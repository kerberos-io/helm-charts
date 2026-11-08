#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

extract_mcp() {
  awk '
    /^---/ { deployment=0; name=""; variable="" }
    /^kind: Deployment$/ { deployment=1 }
    deployment && /^  name:/ { name=$2 }
    /- name: MCP_/ { variable=$3; next }
    variable != "" && /value:/ {
      value=$0
      sub(/^[[:space:]]*value: /, "", value)
      print (deployment ? name : "non-deployment"), variable, value
      variable=""
    }
  ' | sort
}

assert_mcp() {
  local rendered="$1" expected="$2" actual
  actual="$(printf '%s\n' "$rendered" | extract_mcp)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected MCP environment:\n%s\nExpected:\n%s\n' "$actual" "$expected" >&2
    return 1
  fi
}

defaults="$(printf '%s\n' 'hub-api MCP_ALLOWED_ORIGINS ""' 'hub-api MCP_ENABLED "false"')"
enabled="$(printf '%s\n' \
  'hub-api MCP_ALLOWED_ORIGINS "https://agent.example.com,http://localhost:4200"' \
  'hub-api MCP_ENABLED "true"')"
flags=(
  --set kerberoshub.api.mcp.enabled=true
  --set-json 'kerberoshub.api.mcp.allowedOrigins=["https://agent.example.com","http://localhost:4200"]'
)

for mode in all ui pipeline; do
  default_render="$(helm template hub "$CHART_DIR" --set "mode=$mode")"
  configured_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${flags[@]}")"
  helm lint "$CHART_DIR" --quiet --set "mode=$mode" "${flags[@]}"
  if [[ "$mode" == pipeline ]]; then
    assert_mcp "$default_render" ""
    assert_mcp "$configured_render" ""
    [[ "$default_render" == "$configured_render" ]]
  else
    assert_mcp "$default_render" "$defaults"
    assert_mcp "$configured_render" "$enabled"
    rest_default="$(grep -A1 -- '- name: CORS_ALLOWED_ORIGINS' <<< "$default_render")"
    rest_configured="$(grep -A1 -- '- name: CORS_ALLOWED_ORIGINS' <<< "$configured_render")"
    [[ "$rest_default" == "$rest_configured" ]]
  fi
  echo "OK ($mode): MCP defaults, overrides, API-only environment and REST CORS isolation"
done

assert_mcp "$(helm template hub "$CHART_DIR" --set kerberoshub.api.mcp.enabled=true)" \
  "$(printf '%s\n' 'hub-api MCP_ALLOWED_ORIGINS ""' 'hub-api MCP_ENABLED "true"')"
assert_mcp "$(helm template hub "$CHART_DIR" --set kerberoshub.api.mcp=null)" "$defaults"
assert_mcp "$(helm template hub "$CHART_DIR" "${flags[@]}" --set kerberoshub.api.mcp.enabled=false)" \
  "$(printf '%s\n' 'hub-api MCP_ALLOWED_ORIGINS "https://agent.example.com,http://localhost:4200"' 'hub-api MCP_ENABLED "false"')"

expect_invalid() {
  local output
  if output="$(helm template hub "$CHART_DIR" "$@" 2>&1)"; then
    echo "Invalid MCP settings unexpectedly rendered: $*" >&2
    return 1
  fi
  if [[ "$output" != *"mcp"* ]]; then
    printf 'Rendering failed for an unexpected reason:\n%s\n' "$output" >&2
    return 1
  fi
}

expect_invalid --set-string kerberoshub.api.mcp.enabled=true
expect_invalid --set-string kerberoshub.api.mcp.allowedOrigins=https://agent.example.com
expect_invalid --set-string kerberoshub.api.mcp.origin=https://agent.example.com
for origin in 'https://*.example.com' 'https://agent.example.com/' \
  'https://agent.example.com/path' 'https://agent.example.com?query' \
  'https://agent.example.com#fragment' 'https://user@agent.example.com' \
  'https://agent.example.com,https://other.example.com' 'https://bad host' 'ftp://agent.example.com'; do
  expect_invalid --set-json "kerberoshub.api.mcp.allowedOrigins=[\"$origin\"]"
done
expect_invalid --set-json 'kerberoshub.api.mcp.allowedOrigins=["https://agent.example.com","https://agent.example.com"]'

echo "All Hub MCP configuration checks passed."
