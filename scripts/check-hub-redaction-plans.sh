#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

# Prints "<deployment> <variable> <value>" for the redaction plans variables.
extract_plans() {
  awk '
    /^---/ { deployment=0; name=""; variable="" }
    /^kind: Deployment$/ { deployment=1 }
    deployment && /^  name:/ { name=$2 }
    /- name: (FEATURE_)?REDACTION_PLANS_ENABLED$/ { variable=$3; next }
    variable != "" && /value:/ {
      value=$0
      sub(/^[[:space:]]*value: /, "", value)
      print name, variable, value
      variable=""
    }
  ' | sort
}

assert_plans() {
  local rendered="$1" expected="$2" actual
  actual="$(printf '%s\n' "$rendered" | extract_plans)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected redaction plans environment:\n%s\nExpected:\n%s\n' "$actual" "$expected" >&2
    return 1
  fi
}

off="$(printf '%s\n' \
  'hub-api REDACTION_PLANS_ENABLED "false"' \
  'hub-frontend FEATURE_REDACTION_PLANS_ENABLED "false"')"
on="$(printf '%s\n' \
  'hub-api REDACTION_PLANS_ENABLED "true"' \
  'hub-frontend FEATURE_REDACTION_PLANS_ENABLED "true"')"

assert_plans "$(helm template hub "$CHART_DIR")" "$off"
echo "OK: redaction plans are off by default on hub-api and the frontend"

assert_plans "$(helm template hub "$CHART_DIR" --set kerberoshub.api.redactionPlans.enabled=true)" "$on"
echo "OK: one value switches hub-api and the frontend on together"

assert_plans "$(helm template hub "$CHART_DIR" --set-string kerberoshub.api.redactionPlans.enabled=true)" "$on"
echo "OK: the value may be given as a string"

assert_plans "$(helm template hub "$CHART_DIR" --set kerberoshub.api.redactionPlans=null)" "$off"
echo "OK: values files without a redactionPlans section keep it off"

# The face redaction flag of the frontend does not switch plans on.
assert_plans "$(helm template hub "$CHART_DIR" --set kerberoshub.frontend.features.faceRedaction.enabled=true)" "$off"
echo "OK: the face redaction flag alone leaves plans off"

assert_plans "$(helm template hub "$CHART_DIR" --set kerberoshub.api.redactionPlans.enabled=true \
  --set kerberoshub.frontend.demoEnabled=true)" "$(printf '%s\n' \
  'hub-api REDACTION_PLANS_ENABLED "true"' \
  'hub-frontend FEATURE_REDACTION_PLANS_ENABLED "true"' \
  'hub-frontend-demo FEATURE_REDACTION_PLANS_ENABLED "true"')"
echo "OK: the demo frontend follows the same value"

[[ -z "$(helm template hub "$CHART_DIR" --set mode=pipeline --set kerberoshub.api.redactionPlans.enabled=true | extract_plans)" ]]
echo "OK (pipeline): no redaction plans environment"

helm lint "$CHART_DIR" --quiet --set kerberoshub.api.redactionPlans.enabled=true
echo "All Hub redaction plans checks passed."
