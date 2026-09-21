#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"
EXAMPLE="${CHART_DIR}/examples/argocd-pipeline-sync-waves.yaml"

# Only read Deployment metadata, never pod-template or Service annotations.
extract_waves() {
  awk '
    /^---/ { deployment=0; metadata=0; name="" }
    /^kind: Deployment$/ { deployment=1 }
    /^metadata:$/ { metadata=1; next }
    /^[^ #]/ { metadata=0 }
    deployment && metadata && /^  name:/ { name=$2 }
    deployment && metadata && /^    argocd.argoproj.io\/sync-wave:/ {
      value=$2
      gsub(/"/, "", value)
      print name, value
    }
  ' | sort
}

assert_waves() {
  local rendered="$1"
  local expected="$2"
  local actual
  actual="$(printf '%s\n' "$rendered" | extract_waves)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected Deployment waves:\n%s\nExpected:\n%s\n' "$actual" "$expected" >&2
    return 1
  fi
  local all_count expected_count
  all_count="$(printf '%s\n' "$rendered" | grep -c 'argocd.argoproj.io/sync-wave:' || true)"
  expected_count="$(printf '%s\n' "$expected" | awk 'NF { count++ } END { print count+0 }')"
  if [[ "$all_count" != "$expected_count" ]]; then
    echo "Sync-wave annotation leaked outside expected Deployment metadata" >&2
    return 1
  fi
}

expected="$(printf '%s\n' \
  'pipe-event 10' 'pipe-notify 20' 'pipe-throttler 30' 'pipe-analysis 40' \
  'pipe-thumbnail 50' 'pipe-sprite 50' 'pipe-dominantcolor 50' \
  'pipe-counting 50' 'pipe-sequence 60' 'pipe-monitor 70' | sort)"

for mode in all pipeline; do
  default_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" --set kerberospipeline.sprite.enabled=true)"
  assert_waves "$default_render" ""
  if printf '%s\n' "$default_render" | grep -q '^  annotations: null'; then
    echo "Empty annotations must be omitted" >&2
    exit 1
  fi
  example_render="$(helm template hub "$CHART_DIR" -f "$EXAMPLE" --set "mode=$mode" --set kerberospipeline.sprite.enabled=true)"
  assert_waves "$example_render" "$expected"
  echo "OK ($mode): defaults opt out; example assigns all ten Deployment waves"
done

disabled_sprite="$(helm template hub "$CHART_DIR" -f "$EXAMPLE" --set mode=pipeline)"
assert_waves "$disabled_sprite" "$(printf '%s\n' "$expected" | grep -v '^pipe-sprite ')"

ui_render="$(helm template hub "$CHART_DIR" -f "$EXAMPLE" --set mode=ui --set kerberospipeline.sprite.enabled=true)"
assert_waves "$ui_render" ""

# Exercise zero/negative strings and an unrelated annotation on the same map.
for wave in 0 -10; do
  override="$(helm template hub "$CHART_DIR" --set mode=pipeline \
    --set-string "kerberospipeline.event.deploymentAnnotations.argocd\\.argoproj\\.io/sync-wave=$wave" \
    --set-string 'kerberospipeline.event.deploymentAnnotations.example\.com/owner=queue-team')"
  assert_waves "$override" "pipe-event $wave"
  printf '%s\n' "$override" | grep -q "^    argocd.argoproj.io/sync-wave: \"$wave\"$"
  printf '%s\n' "$override" | grep -q '^    example.com/owner: queue-team$'
done

echo "All pipeline Deployment annotation checks passed."
