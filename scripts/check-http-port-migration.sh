#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_KUBECTL="$(command -v kubectl)"
export REAL_KUBECTL

# Substitute only transport: exercise the migration against Kubernetes' real patch engine.
kubectl() {
  if [[ "$*" == *" get deployment "* ]]; then
    printf '%s\n' "$LIVE"
  else
    local patch="" previous="" argument
    for argument in "$@"; do
      if [[ "$previous" == -p ]]; then patch="$argument"; fi
      previous="$argument"
    done
    if [[ "${EXPECT_APPLY:-false}" == true ]]; then
      [[ "$*" != *"--dry-run=server"* ]] || return 1
    else
      [[ "$*" == *"--dry-run=server"* ]] || return 1
    fi
    local current="$LIVE"
    if [[ "${SIMULATE_RACE:-false}" == true ]]; then
      current="$(jq '.metadata.resourceVersion = "2"' <<< "$LIVE")"
    fi
    "$REAL_KUBECTL" patch --local -f <(printf '%s\n' "$current") \
      --type=json -p "$patch" -o json
  fi
}
export -f kubectl

for deployment in admin hub-frontend hub-frontend-demo; do
  for old in 80 8080; do
    target=8080
    if [[ "$old" == 8080 ]]; then target=80; fi
    LIVE="$(jq -nc --arg name "$deployment" --argjson port "$old" '{
      apiVersion: "apps/v1", kind: "Deployment",
      metadata: {name: $name, resourceVersion: "1"},
      spec: {selector: {matchLabels: {app: $name}}, template: {
        metadata: {labels: {app: $name}}, spec: {containers: [
          {name: "sidecar", image: "example/sidecar:unchanged"},
          {name: $name, image: "example/frontend:unchanged", ports: [
            {name: "http", containerPort: $port},
            {name: "metrics", containerPort: 2112}
          ]}
        ]}
      }}
    }')"
    export LIVE
    merge="$(jq -nc --arg name "$deployment" --argjson port "$target" \
      '{spec:{template:{spec:{containers:[{name:$name,ports:[{name:"http",containerPort:$port}]}]}}}}')"
    merged="$("$REAL_KUBECTL" patch --local -f <(printf '%s\n' "$LIVE") \
      --type=strategic -p "$merge" -o json)"
    jq -e '[.spec.template.spec.containers[] | .ports[]? |
      select(.name == "http")] | length == 2' <<< "$merged" > /dev/null

    fixed="$(bash "$ROOT/scripts/migrate-http-port.sh" test "$deployment" "$target")"
    jq -e --argjson port "$target" '
      [.spec.template.spec.containers[] | .ports[]? | select(.name == "http")] |
      length == 1 and .[0].containerPort == $port
    ' <<< "$fixed" > /dev/null
    [[ "$(jq -Sc '.spec.template.spec.containers[0]' <<< "$fixed")" == \
       "$(jq -Sc '.spec.template.spec.containers[0]' <<< "$LIVE")" ]]
    [[ "$(jq -Sc '.spec.template.spec.containers[1] | del(.ports)' <<< "$fixed")" == \
       "$(jq -Sc '.spec.template.spec.containers[1] | del(.ports)' <<< "$LIVE")" ]]
    jq -e '.spec.template.spec.containers[1].ports |
      any(.name == "metrics" and .containerPort == 2112)' <<< "$fixed" > /dev/null

    LIVE="$fixed"
    again="$(EXPECT_APPLY=true bash "$ROOT/scripts/migrate-http-port.sh" test "$deployment" "$target" --apply)"
    [[ "$(jq -Sc . <<< "$again")" == "$(jq -Sc . <<< "$fixed")" ]]
    LIVE="$merged"
    repaired="$(EXPECT_APPLY=true bash "$ROOT/scripts/migrate-http-port.sh" test "$deployment" "$target" --apply)"
    jq -e '[.spec.template.spec.containers[] | .ports[]? |
      select(.name == "http")] | length == 1' <<< "$repaired" > /dev/null

    if [[ "${SERVER_VALIDATION:-false}" == true ]]; then
      if "$REAL_KUBECTL" create --dry-run=server \
        -f <(jq 'del(.metadata.resourceVersion)' <<< "$merged") > /dev/null 2>&1; then
        echo "Expected API rejection of duplicate http ports" >&2
        exit 1
      fi
      "$REAL_KUBECTL" create --dry-run=server \
        -f <(jq 'del(.metadata.resourceVersion)' <<< "$repaired") > /dev/null
    fi
    echo "OK: $deployment $old -> $target; duplicate reproduced, replacement and rollback safe"
  done
done

if SIMULATE_RACE=true bash "$ROOT/scripts/migrate-http-port.sh" test hub-frontend-demo 8080 > /dev/null 2>&1; then
  echo "Expected rejection of concurrent Deployment changes" >&2
  exit 1
fi
LIVE="$(jq '.spec.template.spec.containers[1].ports = [{name:"http",containerPort:9000}]' <<< "$LIVE")"
if bash "$ROOT/scripts/migrate-http-port.sh" test hub-frontend-demo 8080 > /dev/null 2>&1; then
  echo "Expected rejection of an unknown HTTP port" >&2
  exit 1
fi
echo "HTTP port migration checks passed."
