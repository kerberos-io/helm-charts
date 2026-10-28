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

HARDENED_FLAGS=(
  --set admin.containerPort=8080
  --set-json 'admin.securityContext={"runAsNonRoot":true,"runAsUser":65532,"runAsGroup":65532,"readOnlyRootFilesystem":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}'
  --set-json 'admin.volumes=[{"name":"admin-tmp","emptyDir":{"medium":"Memory","sizeLimit":"16Mi"}}]'
  --set-json 'admin.volumeMounts=[{"name":"admin-tmp","mountPath":"/tmp"}]'
  --set-json 'admin.readinessProbe={"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":10}'
  --set-json 'admin.livenessProbe={"httpGet":{"path":"/healthz","port":"http"},"initialDelaySeconds":10,"periodSeconds":10}'
)

for mode in all ui; do
  default_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" --set admin.oauth2Proxy.enabled=true)"
  default_deployment="$(resource deployment <<< "$default_render")"
  default_service="$(resource service <<< "$default_render")"
  default_ingress="$(resource ingress <<< "$default_render")"
  default_oauth="$(resource oauth2-proxy <<< "$default_render")"
  assert_contains "$default_deployment" 'containerPort: 80$'
  assert_absent "$default_deployment" 'securityContext:|readinessProbe:|livenessProbe:'
  assert_contains "$default_service" 'port: 80$'
  assert_contains "$default_service" 'targetPort: http$'

  hardened_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" --set admin.oauth2Proxy.enabled=true "${HARDENED_FLAGS[@]}")"
  hardened_deployment="$(resource deployment <<< "$hardened_render")"
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

  [[ "$(resource service <<< "$hardened_render")" == "$default_service" ]]
  [[ "$(resource ingress <<< "$hardened_render")" == "$default_ingress" ]]
  [[ "$(resource oauth2-proxy <<< "$hardened_render")" == "$default_oauth" ]]
  assert_contains "$default_ingress" 'nginx.ingress.kubernetes.io/auth-url:'
  assert_contains "$default_ingress" 'number: 80$'

  echo "OK ($mode): legacy defaults; hardened runtime/probes; stable Service, ingress and OAuth2"
done

pipeline_render="$(helm template hub "$CHART_DIR" --set mode=pipeline "${HARDENED_FLAGS[@]}")"
assert_absent "$pipeline_render" '^# Source: hub/templates/admin/'

echo "All Admin runtime checks passed."
