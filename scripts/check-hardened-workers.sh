#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"
components=(
  kerberospipeline.counting kerberospipeline.throttler
  kerberospipeline.notify
  kerberospipeline.thumbnail kerberospipeline.dominantColor
  kerberoshub.cleanup kerberoshub.monitordevice
  kerberoshub.services.workflows kerberoshub.services.loitering
)
fixtures=(
  --set kerberospipeline.dominantColor.enabled=true
  --set kerberoshub.workflows.enabled=true
  --set kerberoshub.services.loitering.enabled=true
  --set kerberoshub.services.loitering.repository=example/loitering
  --set kerberoshub.services.loitering.tag=test
  --set kerberoshub.services.loitering.queue=loitering
  --set mongodb.tls.enabled=true
  --set mongodb.tls.existingSecret=mongodb-ca
  --set mongodb.tls.caFileName=ca.crt
)
security=()
for component in "${components[@]}"; do
  security+=(
    --set "$component.securityContext.runAsNonRoot=true"
    --set "$component.securityContext.runAsUser=65532"
    --set "$component.securityContext.runAsGroup=65532"
    --set "$component.securityContext.readOnlyRootFilesystem=true"
    --set "$component.securityContext.allowPrivilegeEscalation=false"
    --set "$component.securityContext.capabilities.drop[0]=ALL"
    --set "$component.securityContext.seccompProfile.type=RuntimeDefault"
    --set "$component.podSecurityContext.fsGroup=65532"
    --set "$component.volumes[0].name=scratch"
    --set "$component.volumes[0].emptyDir.sizeLimit=4Gi"
    --set "$component.volumeMounts[0].name=scratch"
    --set "$component.volumeMounts[0].mountPath=/tmp"
    --set "$component.resources.requests.ephemeral-storage=4Gi"
    --set "$component.resources.limits.ephemeral-storage=6Gi"
  )
done

resource() {
  local kind="$1" name="$2"
  awk -v kind="$kind" -v name="$name" '
    function emit() { if (matchedKind && matchedName) printf "%s", block }
    /^---$/ { emit(); block=""; matchedKind=0; matchedName=0 }
    { block=block $0 "\n" }
    $0 == "kind: " kind { matchedKind=1 }
    $0 == "  name: " name { matchedName=1 }
    END { emit() }
  '
}

assert_line() {
  local block="$1" pattern="$2"
  if ! grep -Eq "$pattern" <<< "$block"; then
    printf 'Missing expected pattern: %s\n%s\n' "$pattern" "$block" >&2
    exit 1
  fi
}

for mode in all pipeline ui; do
  defaults="$(helm template hub "$CHART_DIR" --set "mode=$mode")"
  if grep -q 'securityContext:' <<< "$defaults"; then
    echo "Default $mode mode unexpectedly enables security settings" >&2
    exit 1
  fi

  legacy="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${fixtures[@]}")"
  hardened="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${fixtures[@]}" "${security[@]}")"
  helm lint "$CHART_DIR" --quiet --set "mode=$mode" "${fixtures[@]}" "${security[@]}"
  names=()
  if [[ "$mode" != ui ]]; then
    names+=(pipe-counting pipe-throttler pipe-notify pipe-thumbnail pipe-dominantcolor hub-workflows hub-loitering)
  fi
  if [[ "$mode" != pipeline ]]; then
    names+=(hub-cleanup hub-monitor-device)
  fi
  for name in "${names[@]}"; do
    block="$(resource Deployment "$name" <<< "$hardened")"
    for pattern in \
      '^[ ]{6}securityContext:$' '^[ ]{8}fsGroup: 65532$' \
      '^[ ]+(runAsUser|runAsGroup): 65532$' \
      '^[ ]+runAsNonRoot: true$' '^[ ]+readOnlyRootFilesystem: true$' \
      '^[ ]+allowPrivilegeEscalation: false$' '^[ ]+capabilities:$' \
      '^[ ]+drop:$' '^[ ]+- ALL$' '^[ ]+seccompProfile:$' \
      '^[ ]+type: RuntimeDefault$' '^[ ]+(- )?mountPath: /tmp$' \
      '^[ ]+sizeLimit: 4Gi$' '^[ ]+ephemeral-storage: 6Gi$' \
      '^[ ]+ephemeral-storage: 4Gi$'; do
      assert_line "$block" "$pattern"
    done
    # Verify both identity axes independently.
    assert_line "$block" '^[ ]+runAsUser: 65532$'
    assert_line "$block" '^[ ]+runAsGroup: 65532$'
    assert_line "$block" '^[ ]{8,10}securityContext:$'
    if [[ "$name" == hub-cleanup || "$name" == hub-monitor-device || "$name" == hub-workflows || "$name" == pipe-notify ]]; then
      assert_line "$block" '^[ ]+secretName: mongodb-ca$'
      assert_line "$block" '^[ ]+mountPath: /etc/mongodb/tls$'
      assert_line "$block" '^[ ]+readOnly: true$'
    fi
    if [[ "$name" == pipe-notify ]]; then
      # Provider, queue, FFmpeg and all other worker settings are unchanged.
      old_block="$(resource Deployment pipe-notify <<< "$legacy")"
      [[ "$(sed -n '/^        env:/,$p' <<< "$old_block")" == "$(sed -n '/^        env:/,$p' <<< "$block")" ]]
    fi
    if [[ "$name" != hub-monitor-device ]]; then
      service="$(resource Service "$name" <<< "$hardened")"
      assert_line "$service" '^[ ]+port: 8080$'
      assert_line "$service" '^[ ]+targetPort: 8080$'
    fi
  done
  expected="${#names[@]}"
  [[ "$(grep -c 'runAsUser: 65532' <<< "$hardened")" == "$expected" ]]
  [[ "$(grep -c 'fsGroup: 65532' <<< "$hardened")" == "$expected" ]]

  # Image selection, Services, env and TLS mounts must not change.
  for pattern in '^[ ]+image:' '^[ ]+(port|targetPort|containerPort):' 'mongodb-tls'; do
    [[ "$(grep -E "$pattern" <<< "$legacy")" == "$(grep -E "$pattern" <<< "$hardened")" ]]
  done
  echo "OK ($mode): defaults unchanged; $expected independent hardened workers preserve images, ports and MongoDB TLS"
done

# Hardening one worker must not opt in another, even on the same pod mode.
isolated="$(helm template hub "$CHART_DIR" --set mode=pipeline \
  --set kerberospipeline.counting.securityContext.runAsUser=65532)"
[[ "$(grep -c 'runAsUser: 65532' <<< "$isolated")" == 1 ]]
assert_line "$(resource Deployment pipe-counting <<< "$isolated")" '^[ ]+runAsUser: 65532$'
echo "All hardened worker checks passed."

admin_flags=(
  --set admin.containerPort=8080
  --set admin.securityContext.runAsNonRoot=true
  --set admin.securityContext.runAsUser=65532
  --set admin.securityContext.runAsGroup=65532
  --set admin.securityContext.readOnlyRootFilesystem=true
  --set admin.securityContext.allowPrivilegeEscalation=false
  --set admin.securityContext.capabilities.drop[0]=ALL
  --set admin.securityContext.seccompProfile.type=RuntimeDefault
  --set admin.volumes[0].name=admin-tmp
  --set admin.volumes[0].emptyDir.medium=Memory
  --set admin.volumes[0].emptyDir.sizeLimit=16Mi
  --set admin.volumeMounts[0].name=admin-tmp
  --set admin.volumeMounts[0].mountPath=/tmp
  --set admin.oauth2Proxy.enabled=true
)
for mode in all ui pipeline; do
  legacy="$(helm template hub "$CHART_DIR" --set "mode=$mode" --set admin.oauth2Proxy.enabled=true)"
  configured="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${admin_flags[@]}")"
  helm lint "$CHART_DIR" --quiet --set "mode=$mode" "${admin_flags[@]}"
  if [[ "$mode" == pipeline ]]; then
    [[ -z "$(resource Deployment admin <<< "$configured")" ]]
    [[ -z "$(resource Service admin-svc <<< "$configured")" ]]
    [[ "$legacy" == "$configured" ]]
    echo "OK (pipeline): Admin settings render no Admin resources or unrelated changes"
    continue
  fi
  old="$(resource Deployment admin <<< "$legacy")"
  block="$(resource Deployment admin <<< "$configured")"
  assert_line "$old" '^[ ]+containerPort: 80$'
  [[ "$old" != *securityContext:* && "$old" != *admin-tmp* ]]
  for pattern in \
    '^[ ]+containerPort: 8080$' '^[ ]{10}securityContext:$' \
    '^[ ]+runAsUser: 65532$' '^[ ]+runAsGroup: 65532$' \
    '^[ ]+runAsNonRoot: true$' '^[ ]+readOnlyRootFilesystem: true$' \
    '^[ ]+allowPrivilegeEscalation: false$' '^[ ]+capabilities:$' \
    '^[ ]+drop:$' '^[ ]+- ALL$' '^[ ]+seccompProfile:$' \
    '^[ ]+type: RuntimeDefault$' '^[ ]+medium: Memory$' \
    '^[ ]+sizeLimit: 16Mi$' '^[ ]+(- )?mountPath: /tmp$'; do
    assert_line "$block" "$pattern"
  done
  old_service="$(resource Service admin-svc <<< "$legacy")"
  service="$(resource Service admin-svc <<< "$configured")"
  assert_line "$old_service" '^[ ]+targetPort: http$'
  assert_line "$service" '^[ ]+port: 80$'
  assert_line "$service" '^[ ]+targetPort: http$'
  [[ "$(resource Ingress admin-ingress <<< "$legacy")" == "$(resource Ingress admin-ingress <<< "$configured")" ]]
  [[ "$(resource Deployment oauth2-proxy-admin <<< "$legacy")" == "$(resource Deployment oauth2-proxy-admin <<< "$configured")" ]]
  [[ "$(resource Service oauth2-proxy-admin <<< "$legacy")" == "$(resource Service oauth2-proxy-admin <<< "$configured")" ]]
  [[ "$(grep 'image:' <<< "$legacy")" == "$(grep 'image:' <<< "$configured")" ]]
  # No other workload inherits Admin's container port or security settings.
  [[ "$(grep -c 'runAsUser: 65532' <<< "$configured")" == 1 ]]
  echo "OK ($mode): Admin opt-in port/security/tmpfs; legacy image, Service port, ingress and OAuth2-proxy preserved"
done
echo "All hardened Admin checks passed."
