#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

# Prints "<deployment> <variable> <value>" for every ASK_ and FEATURE_ASK_ variable.
extract_ask() {
  awk '
    /^---/ { deployment=0; name=""; variable="" }
    /^kind: Deployment$/ { deployment=1 }
    deployment && /^  name:/ { name=$2 }
    /- name: (FEATURE_)?ASK_/ { variable=$3; next }
    variable != "" && /value:/ {
      value=$0
      sub(/^[[:space:]]*value: /, "", value)
      print name, variable, value
      variable=""
    }
  ' | sort
}

assert_ask() {
  local rendered="$1" expected="$2" actual
  actual="$(printf '%s\n' "$rendered" | extract_ask)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected Ask environment:\n%s\nExpected:\n%s\n' "$actual" "$expected" >&2
    return 1
  fi
}

model=(
  --set kerberoshub.api.ask.azureOpenAI.endpoint=https://ask.example.openai.azure.com
  --set kerberoshub.api.ask.azureOpenAI.apiKey=test-key
  --set kerberoshub.api.ask.azureOpenAI.deployment=ask-model
  --set kerberoshub.api.ask.azureOpenAI.reasoningEffort=low
)

assert_ask "$(helm template hub "$CHART_DIR")" "$(printf '%s\n' \
  'hub-api ASK_ENABLED "false"' \
  'hub-frontend FEATURE_ASK_ENABLED "false"')"
echo "OK: Ask is off by default and passes no model settings"

assert_ask "$(helm template hub "$CHART_DIR" --set kerberoshub.api.ask.enabled=true \
  --set kerberoshub.frontend.features.ask.enabled=true "${model[@]}")" "$(printf '%s\n' \
  'hub-api ASK_AZURE_OPENAI_API_KEY "test-key"' \
  'hub-api ASK_AZURE_OPENAI_DEPLOYMENT "ask-model"' \
  'hub-api ASK_AZURE_OPENAI_ENDPOINT "https://ask.example.openai.azure.com"' \
  'hub-api ASK_AZURE_OPENAI_REASONING_EFFORT "low"' \
  'hub-api ASK_ENABLED "true"' \
  'hub-frontend FEATURE_ASK_ENABLED "true"')"
echo "OK: enabled Ask passes the model settings to hub-api only"

assert_ask "$(helm template hub "$CHART_DIR" --set kerberoshub.api.ask=null --set kerberoshub.frontend.features.ask=null)" \
  "$(printf '%s\n' 'hub-api ASK_ENABLED "false"' 'hub-frontend FEATURE_ASK_ENABLED "false"')"
echo "OK: values files without an ask section keep it off"

[[ -z "$(helm template hub "$CHART_DIR" --set mode=pipeline --set kerberoshub.api.ask.enabled=true "${model[@]}" | extract_ask)" ]]
echo "OK (pipeline): no Ask environment"

for missing in endpoint apiKey deployment; do
  if output="$(helm template hub "$CHART_DIR" --set kerberoshub.api.ask.enabled=true "${model[@]}" \
    --set "kerberoshub.api.ask.azureOpenAI.$missing=" 2>&1)"; then
    echo "Rendering succeeded without azureOpenAI.$missing" >&2
    exit 1
  fi
  grep -q "kerberoshub.api.ask.azureOpenAI.$missing is required" <<< "$output"
done
echo "OK: enabled Ask requires endpoint, apiKey and deployment"

helm lint "$CHART_DIR" --quiet --set kerberoshub.api.ask.enabled=true "${model[@]}"
echo "All Hub Ask configuration checks passed."
