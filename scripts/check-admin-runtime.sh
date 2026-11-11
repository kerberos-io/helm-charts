#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

resource() {
  local source="$1"
  awk -v source="# Source: hub/templates/admin/$source.yaml" '
    /^---/ { selected=0 }
    /^# Source:/ { selected=($0 == source); next }
    selected { print }
  '
}

assert_contains() {
  local rendered="$1" pattern="$2"
  if ! grep -Eq -- "$pattern" <<< "$rendered"; then
    printf 'Missing expected Admin setting: %s\n' "$pattern" >&2
    return 1
  fi
}

assert_absent() {
  local rendered="$1" pattern="$2"
  if grep -Eq -- "$pattern" <<< "$rendered"; then
    printf 'Unexpected Admin setting: %s\n' "$pattern" >&2
    return 1
  fi
}

# Since chart 0.184.0 the hardened ghcr.io/uug-ai/admin runtime is the default;
# LEGACY_FLAGS opts back into a legacy image on port 80.
LEGACY_FLAGS=(
  --set admin.repository=uugai/admin
  --set admin.tag=v1.3.0
  --set admin.containerPort=80
  --set admin.securityContext=null
  --set admin.readinessProbe=null
  --set admin.livenessProbe=null
  --set admin.volumes=null
  --set admin.volumeMounts=null
)

for mode in all ui; do
  hardened_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" --set admin.oauth2Proxy.enabled=true)"
  hardened_deployment="$(resource deployment <<< "$hardened_render")"
  hardened_service="$(resource service <<< "$hardened_render")"
  hardened_ingress="$(resource ingress <<< "$hardened_render")"
  hardened_oauth="$(resource oauth2-proxy <<< "$hardened_render")"
  assert_contains "$hardened_deployment" 'image: "ghcr.io/uug-ai/admin:'
  assert_contains "$hardened_deployment" 'containerPort: 8080$'
  assert_absent "$hardened_deployment" 'containerPort: 80$'
  for setting in 'runAsNonRoot: true' 'runAsUser: 65532' 'runAsGroup: 65532' \
    'readOnlyRootFilesystem: true' 'allowPrivilegeEscalation: false' \
    'type: RuntimeDefault' 'drop:' '- ALL' 'medium: Memory' \
    'sizeLimit: 16Mi' 'mountPath: /tmp' 'name: admin-tmp'; do
    assert_contains "$hardened_deployment" "^[[:space:]]*(- )?$setting$"
  done
  for probe in readinessProbe livenessProbe; do
    probe_render="$(awk -v probe="$probe:" '
      /^          [a-zA-Z]/ { selected=($1 == probe) }
      selected { print }
    ' <<< "$hardened_deployment")"
    assert_contains "$probe_render" 'path: /healthz$'
    assert_contains "$probe_render" 'port: http$'
  done
  assert_contains "$hardened_service" 'port: 80$'
  assert_contains "$hardened_service" 'targetPort: http$'

  legacy_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" --set admin.oauth2Proxy.enabled=true "${LEGACY_FLAGS[@]}")"
  legacy_deployment="$(resource deployment <<< "$legacy_render")"
  assert_contains "$legacy_deployment" 'containerPort: 80$'
  assert_absent "$legacy_deployment" 'securityContext:|readinessProbe:|livenessProbe:|admin-tmp'

  [[ "$(resource service <<< "$legacy_render")" == "$hardened_service" ]]
  [[ "$(resource ingress <<< "$legacy_render")" == "$hardened_ingress" ]]
  [[ "$(resource oauth2-proxy <<< "$legacy_render")" == "$hardened_oauth" ]]
  assert_contains "$hardened_ingress" 'nginx.ingress.kubernetes.io/auth-url:'
  assert_contains "$hardened_ingress" 'number: 80$'

  echo "OK ($mode): hardened ghcr.io defaults; legacy opt-out; stable Service, ingress and OAuth2"
done

pipeline_render="$(helm template hub "$CHART_DIR" --set mode=pipeline)"
assert_absent "$pipeline_render" '^# Source: hub/templates/admin/'

echo "All Admin runtime checks passed."
