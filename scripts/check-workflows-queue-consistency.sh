#!/usr/bin/env bash
#
# Render the hub chart and assert that every deployment which carries the
# workflows hand-off queue (the WORKFLOWS_QUEUE env var) resolves to the SAME,
# non-empty value.
#
# Why: the analysis pipeline (pipe-analysis) publishes opened workflow runs to
# WORKFLOWS_QUEUE, the workflows engine (hub-workflows) consumes it, and every
# stage worker (hub-stage) routes its result back to it. All three templates
# read the single key `kerberoshub.services.workflows.queue`. If a future edit
# hardcodes a value, reads the wrong key, or drops the env on one of them, the
# producer and consumer silently drift onto different queue names and messages
# pile up with no consumer. This check fails the build before that can ship.
#
# Also checks workflow identity validation and identical WORKFLOW_DEFINITIONS
# in the API and engine. Requires Helm and Python 3 (standard library only).
#
# Usage: scripts/check-workflows-queue-consistency.sh [chart-dir]
#        (chart-dir defaults to charts/hub, relative to the repo root)

set -euo pipefail

CHART_DIR="${1:-charts/hub}"
PROBE="drift-probe-queue-name"

# Flags that force all three deployment kinds (analysis, engine and one stage
# worker) to render, so the check actually has something to compare. The chart
# ships NO enabled stage worker by default (custom stages are values-only and
# opt-in), so we synthesise a throwaway stage purely to exercise the generic
# hub-stage path. The name is a neutral fixture ("queuecheck") on purpose: any
# arbitrary stage key must render the same way, so the check must not depend on
# a specific bundled worker.
STAGE="queuecheck"
RENDER_FLAGS=(
  --set mode=all
  --set kerberoshub.workflows.enabled=true
  --set "kerberoshub.workflows.stages.${STAGE}.enabled=true"
  --set "kerberoshub.services.${STAGE}.enabled=true"
  --set "kerberoshub.services.${STAGE}.repository=example.invalid/queuecheck"
  --set "kerberoshub.services.${STAGE}.tag=test"
  --set "kerberoshub.services.${STAGE}.queue=queuecheck-fixture-queue"
)

# Read `helm template` output on stdin and print one WORKFLOWS_QUEUE value per
# line. Matches the `- name: WORKFLOWS_QUEUE` env entry and captures the value
# from the following `value:` line, skipping blank/comment lines in between.
extract_workflows_queue() {
  awk '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*WORKFLOWS_QUEUE[[:space:]]*$/ { want=1; next }
    want==1 {
      if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) next
      v=$0
      sub(/^[[:space:]]*value:[[:space:]]*/, "", v)
      sub(/^"/, "", v); sub(/"[[:space:]]*$/, "", v)
      sub(/[[:space:]]+$/, "", v)
      print v
      want=0
    }
  '
}

assert_all_equal() {
  local expected="$1"; shift
  local label="$1"; shift
  local -a vals=("$@")

  if [ "${#vals[@]}" -lt 2 ]; then
    echo "FAIL (${label}): expected at least 2 WORKFLOWS_QUEUE values (analysis + engine), found ${#vals[@]}" >&2
    return 1
  fi

  local v
  for v in "${vals[@]}"; do
    if [ -z "${v}" ]; then
      echo "FAIL (${label}): a deployment rendered an empty WORKFLOWS_QUEUE value" >&2
      return 1
    fi
    if [ "${v}" != "${expected}" ]; then
      echo "FAIL (${label}): WORKFLOWS_QUEUE drift detected — expected '${expected}' but a deployment rendered '${v}'" >&2
      printf '  rendered values: %s\n' "${vals[*]}" >&2
      return 1
    fi
  done

  echo "OK (${label}): ${#vals[@]} deployments all use WORKFLOWS_QUEUE='${expected}'"
}

echo "== Rendering ${CHART_DIR} with the chart's default workflows queue =="
default_out="$(helm template hub "${CHART_DIR}" "${RENDER_FLAGS[@]}")"
mapfile -t default_vals < <(printf '%s\n' "${default_out}" | extract_workflows_queue)
default_queue="${default_vals[0]:-}"
assert_all_equal "${default_queue}" "default values" "${default_vals[@]}" || exit 1

echo "== Rendering ${CHART_DIR} with an overridden workflows queue (-> ${PROBE}) =="
probe_out="$(helm template hub "${CHART_DIR}" "${RENDER_FLAGS[@]}" \
  --set kerberoshub.services.workflows.queue="${PROBE}")"
mapfile -t probe_vals < <(printf '%s\n' "${probe_out}" | extract_workflows_queue)
assert_all_equal "${PROBE}" "override probe" "${probe_vals[@]}" || exit 1

assert_definitions() {
  local rendered="$1" expected="$2" label="$3"
  printf '%s\n' "$rendered" | python3 -c '
import json
import re
import sys

expected = json.loads(sys.argv[1])
label = sys.argv[2]
actual = {}
for document in sys.stdin.read().split("\n---"):
    match = re.search(r"(?m)^[ \t]*- name: WORKFLOW_DEFINITIONS[ \t]*\n[ \t]*value: (\".*\")$", document)
    if not match:
        continue
    name = re.search(r"(?m)^metadata:\n  name: (.+)$", document).group(1)
    assert name not in actual, f"duplicate WORKFLOW_DEFINITIONS in {name}"
    actual[name] = json.loads(json.loads(match.group(1)))
assert set(actual) == {"hub-api", "hub-workflows"}, f"unexpected deployments: {set(actual)}"
for name, definitions in actual.items():
    assert definitions == expected, f"{label}: {name}: {definitions!r} != {expected!r}"
print(f"OK ({label}): API and engine receive identical expected workflow definitions")
' "$expected" "$label"
}

assert_render_failure() {
  local label="$1" expected="$2"; shift 2
  local output
  if output="$(helm template hub "${CHART_DIR}" "${RENDER_FLAGS[@]}" "$@" 2>&1)"; then
    echo "FAIL (${label}): Helm accepted invalid workflow identities" >&2
    return 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    printf 'FAIL (%s): expected diagnostic %s, got:\n%s\n' "$label" "$expected" "$output" >&2
    return 1
  fi
  echo "OK (${label}): Helm rejected invalid workflow identities"
}

assert_definitions "$default_out" '[]' "empty defaults"

echo "== Checking explicit and legacy workflow definitions =="
identity_fixture='{
  " Legacy Workflow ": {
    "enabled": true,
    "stages": [
      {"operation": "queuecheck"},
      {"operation": "external", "dispatch": "conditional", "needs": [{"operation": "queuecheck"}], "needsMode": "all"}
    ]
  },
  "explicit": {
    "id": "ABCDEF0123456789ABCDEF01",
    "enabled": true,
    "triggers": [{"type": "automatic", "devices": [{"key": "fixture-device"}]}],
    "stages": []
  },
  "disabled": {"id": "abcdef0123456789abcdef02", "enabled": false}
}'
expected_definitions='[
  {
    "name": " Legacy Workflow ", "enabled": true, "source": "config",
    "triggers": [{"type": "automatic"}],
    "stages": [
      {"operation": "queuecheck", "dispatch": "always", "queue": "queuecheck-fixture-queue"},
      {"operation": "external", "dispatch": "conditional", "needs": [{"operation": "queuecheck"}], "needsMode": "all"}
    ]
  },
  {
    "name": "explicit", "id": "abcdef0123456789abcdef01", "enabled": true, "source": "config",
    "triggers": [{"type": "automatic", "devices": [{"key": "fixture-device"}]}],
    "stages": []
  }
]'
identity_out="$(helm template hub "${CHART_DIR}" "${RENDER_FLAGS[@]}" \
  --set-json "kerberoshub.workflows.definitions=$identity_fixture")"
assert_definitions "$identity_out" "$expected_definitions" "explicit ID lowercase; legacy omission; disabled filtering; triggers and stages unchanged"

renamed_out="$(helm template hub "${CHART_DIR}" "${RENDER_FLAGS[@]}" \
  --set-json "kerberoshub.workflows.definitions=${identity_fixture/\"explicit\"/\"renamed\"}")"
assert_definitions "$renamed_out" "${expected_definitions/\"explicit\"/\"renamed\"}" "explicit identity survives rename"

legacy_only_out="$(helm template hub "${CHART_DIR}" "${RENDER_FLAGS[@]}" \
  --set-json 'kerberoshub.workflows.definitions={"legacy":{"enabled":true}}')"
assert_definitions "$legacy_only_out" \
  '[{"name":"legacy","enabled":true,"source":"config","triggers":[{"type":"automatic"}],"stages":[]}]' \
  "legacy-only values unchanged"

echo "== Checking bundled example identity pins =="
python3 - "$CHART_DIR/values.yaml" <<'PY'
import hashlib
import pathlib
import re
import sys

values = pathlib.Path(sys.argv[1]).read_text()
for name in ("tracking-workflow", "vlm-workflow"):
    expected = hashlib.sha256(name.encode()).hexdigest()[:24]
    match = re.search(r"(?m)^    #  " + re.escape(name) + r':\n    #    id: "([^"]+)"$', values)
    assert match and match.group(1) == expected, f"{name} must preserve its name-derived ID {expected}"
    print(f"OK ({name}): example pins existing identity {expected}")
PY

echo "== Rejecting invalid explicit IDs, including disabled definitions =="
invalid_ids=('""' 'null' '"000000000000000000000000"' '0' '123' 'true' 'false' '[]' '{}'
  '"abc"' '"zzzzzzzzzzzzzzzzzzzzzzzz"' '"abcdef0123456789abcdef01 "'
  '"abcdef0123456789abcdef0"' '"abcdef0123456789abcdef012"')
invalid_diagnostic='kerberoshub.workflows.definitions["invalid"].id must be a non-zero 24-character hexadecimal string'
for enabled in true false; do
  for id in "${invalid_ids[@]}"; do
    assert_render_failure "id=$id, enabled=$enabled" "$invalid_diagnostic" \
      --set-json "kerberoshub.workflows.definitions={\"invalid\":{\"enabled\":$enabled,\"id\":$id}}"
  done
done

# Validation must not depend on either consumer being rendered.
for mode in all ui pipeline; do
  assert_render_failure "engine disabled, mode=$mode" "$invalid_diagnostic" \
    --set "mode=$mode" --set kerberoshub.workflows.enabled=false \
    --set-json 'kerberoshub.workflows.definitions={"invalid":{"enabled":false,"id":null}}'
done

echo "== Rejecting duplicate effective IDs =="
legacy_id="$(python3 -c 'import hashlib; print(hashlib.sha256(b" Legacy Workflow ").hexdigest()[:24])')"
for first_enabled in true false; do
  for second_enabled in true false; do
    assert_render_failure "explicit collision, enabled=$first_enabled/$second_enabled" \
      'duplicate effective workflow id "abcdef0123456789abcdef01" for "first" and "second"' \
      --set-json "kerberoshub.workflows.definitions={\"first\":{\"enabled\":$first_enabled,\"id\":\"ABCDEF0123456789ABCDEF01\"},\"second\":{\"enabled\":$second_enabled,\"id\":\"abcdef0123456789abcdef01\"}}"
    assert_render_failure "explicit/derived collision, enabled=$first_enabled/$second_enabled" \
      "duplicate effective workflow id \"$legacy_id\" for \" Legacy Workflow \" and \"explicit\"" \
      --set-json "kerberoshub.workflows.definitions={\" Legacy Workflow \":{\"enabled\":$first_enabled},\"explicit\":{\"enabled\":$second_enabled,\"id\":\"${legacy_id^^}\"}}"
  done
done

echo "All workflow queue and identity checks passed."
