#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

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
  if ! grep -Eq -- "$2" <<< "$1"; then
    printf 'Missing expected Hub API setting: %s\n' "$2" >&2
    exit 1
  fi
}

fixtures=(
  --set workflowConfiguration.enabled=true
  --set mongodb.tls.enabled=true
  --set mongodb.tls.existingSecret=mongodb-ca
  --set kerberoshub.api.serverTLS.enabled=true
  --set kerberoshub.api.serverTLS.secretName=api-tls
)

for mode in all ui pipeline; do
  defaults="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${fixtures[@]}")"
  legacy="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${fixtures[@]}" \
    --set kerberoshub.api.securityContext=null \
    --set kerberoshub.api.podSecurityContext=null)"
  configured="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${fixtures[@]}" \
    --set kerberoshub.api.securityContext.runAsUser=1000 \
    --set kerberoshub.api.securityContext.runAsGroup=1000 \
    --set kerberoshub.api.podSecurityContext.fsGroup=1000)"
  helm lint "$CHART_DIR" --quiet --set "mode=$mode" "${fixtures[@]}"

  if [[ "$mode" == pipeline ]]; then
    [[ -z "$(resource Deployment hub-api <<< "$defaults")" ]]
    [[ "$defaults" == "$legacy" && "$defaults" == "$configured" ]]
    echo "OK (pipeline): no Hub API resources or unrelated changes"
    continue
  fi

  api="$(resource Deployment hub-api <<< "$defaults")"
  for pattern in \
    '^[ ]{6}securityContext:$' '^[ ]{8}fsGroup: 65532$' \
    '^[ ]{10}securityContext:$' '^[ ]{12}runAsUser: 65532$' \
    '^[ ]{12}runAsGroup: 65532$' '^[ ]{12}runAsNonRoot: true$' \
    '^[ ]{12}readOnlyRootFilesystem: true$' \
    '^[ ]{12}allowPrivilegeEscalation: false$' '^[ ]{12}capabilities:$' \
    '^[ ]{14}drop:$' '^[ ]{14}- ALL$' \
    '^[ ]{12}seccompProfile:$' '^[ ]{14}type: RuntimeDefault$' \
    '^[ ]+(- )?name: hub-api-tmp$' '^[ ]+(- )?emptyDir: \{\}$' \
    '^[ ]+(- )?mountPath: /tmp$' '^[ ]+secretName: mongodb-ca$' \
    '^[ ]+secretName: api-tls$' '^[ ]+mountPath: /etc/mongodb/tls$' \
    '^[ ]+mountPath: /etc/hub-api/tls$' \
    '^[ ]+mountPath: /etc/kerberos/configuration$' \
    '^[ ]+mountPath: /etc/kerberos/classifications$'; do
    assert_line "$api" "$pattern"
  done
  [[ "$(grep -c 'securityContext:' <<< "$api")" == 2 ]]
  old_api="$(resource Deployment hub-api <<< "$legacy")"
  if grep -q 'securityContext:' <<< "$old_api"; then
    echo "Legacy Hub API opt-out still renders a security context" >&2
    exit 1
  fi
  custom_api="$(resource Deployment hub-api <<< "$configured")"
  for field in runAsUser runAsGroup fsGroup; do
    assert_line "$custom_api" "^[ ]+$field: 1000$"
  done

  # Only security settings change; preserve env, mounts, images and routing.
  for pattern in '^[ ]+image:' '^[ ]+(port|targetPort|containerPort):' \
    '^[ ]+(- )?(name|mountPath|secretName|value):'; do
    [[ "$(grep -E "$pattern" <<< "$defaults")" == "$(grep -E "$pattern" <<< "$legacy")" ]]
    [[ "$(grep -E "$pattern" <<< "$defaults")" == "$(grep -E "$pattern" <<< "$configured")" ]]
  done
  echo "OK ($mode): API security defaults, overrides, opt-out, scratch and TLS/config mounts"
done
