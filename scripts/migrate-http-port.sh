#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: bash scripts/migrate-http-port.sh NAMESPACE DEPLOYMENT PORT [--apply]" >&2
  exit 1
fi
namespace="$1" deployment="$2" port="$3"
case "$deployment" in
  admin|hub-frontend|hub-frontend-demo) ;;
  *) echo "Unsupported Deployment: $deployment" >&2; exit 1 ;;
esac
case "$port" in
  80|8080) ;;
  *) echo "Expected HTTP port 80 or 8080, got: $port" >&2; exit 1 ;;
esac
dry_run=(--dry-run=server)
if [[ $# -eq 4 ]]; then
  if [[ "$4" != --apply ]]; then
    echo "Unknown option: $4" >&2
    exit 1
  fi
  dry_run=()
fi

live="$(kubectl -n "$namespace" get deployment "$deployment" -o json)"
patch="$(jq -ce --arg container "$deployment" --argjson port "$port" '
  . as $deployment |
  [.spec.template.spec.containers | to_entries[] |
    select(.value.name == $container)] |
  if length != 1 then error("Expected exactly one matching container") else .[0] end |
  .key as $index | .value.ports as $ports |
  if ($ports | type) != "array" then error("Container ports must be an array") else . end |
  [$ports[] | select(.name == "http")] as $http |
  if ($http | length) == 0 then error("No named http port to migrate") else . end |
  if any($http[]; (.containerPort != 80 and .containerPort != 8080) or
    ((.protocol // "TCP") != "TCP") or has("hostPort") or has("hostIP"))
  then error("Unsupported http port configuration; migrate manually") else . end |
  if any($ports[]; .name != "http" and .containerPort == $port and
    ((.protocol // "TCP") == "TCP"))
  then error("Target port is already used by another named port") else . end |
  ([$ports[] | select(.name != "http")] +
    [($http[0] + {containerPort: $port})]) as $replacement |
  [
    {op: "test", path: "/metadata/resourceVersion", value: $deployment.metadata.resourceVersion},
    {op: "test", path: ("/spec/template/spec/containers/" + ($index | tostring) + "/name"),
      value: $container},
    {op: "replace", path: ("/spec/template/spec/containers/" + ($index | tostring) + "/ports"),
      value: $replacement}
  ]
' <<< "$live")"

kubectl -n "$namespace" patch deployment "$deployment" --type=json \
  -p "$patch" "${dry_run[@]}" -o yaml
