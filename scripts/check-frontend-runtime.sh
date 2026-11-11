#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"
values=()
if [[ $# -ge 2 ]]; then values=(--values "$2"); fi

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

assert_contains() {
  if ! grep -Eq -- "$2" <<< "$1"; then
    printf 'Missing expected frontend setting: %s\n' "$2" >&2
    exit 1
  fi
}

for mode in all ui; do
  rendered="$(helm template hub "$CHART_DIR" "${values[@]}" --set "mode=$mode" \
    --set kerberoshub.frontend.demoEnabled=true)"
  for name in hub-frontend hub-frontend-demo; do
    deployment="$(resource Deployment "$name" <<< "$rendered")"
    assert_contains "$deployment" 'image: "ghcr.io/uug-ai/hub-frontend:v1.19.35"$'
    assert_contains "$deployment" 'containerPort: 8080$'
    [[ "$(grep -c 'containerPort:' <<< "$deployment")" == 1 ]]
    for setting in 'name: http' 'runAsNonRoot: true' 'runAsUser: 65532' \
      'runAsGroup: 65532' 'readOnlyRootFilesystem: true' \
      'allowPrivilegeEscalation: false' 'type: RuntimeDefault' 'drop:' '- ALL' \
      'medium: Memory' 'sizeLimit: 16Mi' 'mountPath: /tmp' 'name: frontend-tmp'; do
      assert_contains "$deployment" "^[[:space:]]*(- )?$setting$"
    done
    service="$(resource Service "$name-svc" <<< "$rendered")"
    assert_contains "$service" 'port: 80$'
    assert_contains "$service" 'targetPort: http$'
    echo "OK ($mode): $name hardened image, security, scratch and named routing"
  done
  admin="$(resource Deployment admin <<< "$rendered")"
  assert_contains "$admin" 'containerPort: 8080$'

  legacy="$(helm template hub "$CHART_DIR" "${values[@]}" --set "mode=$mode" \
    --set kerberoshub.frontend.demoEnabled=true \
    --set kerberoshub.frontend.tag=v1.13.9 \
    --set kerberoshub.frontend.containerPort=80 \
    --set kerberoshub.frontend.securityContext=null \
    --set-json 'kerberoshub.frontend.volumes=[]' \
    --set-json 'kerberoshub.frontend.volumeMounts=[]')"
  for name in hub-frontend hub-frontend-demo; do
    deployment="$(resource Deployment "$name" <<< "$legacy")"
    assert_contains "$deployment" 'containerPort: 80$'
    assert_contains "$deployment" 'image: "ghcr.io/uug-ai/hub-frontend:v1.13.9"$'
    if grep -Eq 'securityContext:|mountPath: /tmp' <<< "$deployment"; then
      echo "Legacy frontend retains incompatible hardened runtime settings" >&2
      exit 1
    fi
  done
done

if [[ "${CLUSTER_SMOKE:-false}" == true ]]; then
  namespace=frontend-runtime-test
  kubectl create namespace "$namespace"
  helm template runtime "$CHART_DIR" "${values[@]}" --namespace "$namespace" \
    --set mode=ui --set ingress="" --set kerberoshub.frontend.demoEnabled=true \
    --show-only templates/kerberos-hub/hub-frontend.yaml \
    --show-only templates/kerberos-hub/hub-frontend-demo.yaml | kubectl apply -f -
  pid=""
  cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid"; fi
    if [[ "$1" != 0 ]]; then
      kubectl -n "$namespace" get pods
      kubectl -n "$namespace" describe pods
      kubectl -n "$namespace" logs -l app=hub-frontend --all-containers=true
      kubectl -n "$namespace" logs -l app=hub-frontend-demo --all-containers=true
    fi
  }
  trap 'cleanup "$?"' EXIT
  for name in hub-frontend hub-frontend-demo; do
    kubectl -n "$namespace" rollout status "deployment/$name" --timeout=180s
    kubectl -n "$namespace" port-forward "service/$name-svc" 18080:80 &
    pid=$!
    for attempt in {1..30}; do
      if curl --fail --silent http://127.0.0.1:18080/healthz > /dev/null; then break; fi
      sleep 1
    done
    [[ "$(curl --fail --silent http://127.0.0.1:18080/healthz)" == ok ]]
    curl --fail --silent http://127.0.0.1:18080/assets/env.js | grep 'window' > /dev/null
    kill "$pid"
    wait "$pid" || [[ "$?" == 143 ]]
    pid=""
    echo "OK: $name serves health and generated runtime configuration through Service port 80"
  done
fi

echo "Frontend runtime checks passed."
