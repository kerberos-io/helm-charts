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

echo "All WORKFLOWS_QUEUE consistency checks passed."
