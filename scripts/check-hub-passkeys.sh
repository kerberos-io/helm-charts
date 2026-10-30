#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

extract_passkeys() {
  awk '
    /^---/ { deployment=0; name=""; variable="" }
    /^kind: Deployment$/ { deployment=1 }
    deployment && /^  name:/ { name=$2 }
    deployment && /- name: PASSKEY_/ { variable=$3; next }
    variable != "" && /value:/ {
      value=$0
      sub(/^[[:space:]]*value: /, "", value)
      print name, variable, value
      variable=""
    }
  ' | sort
}

assert_passkeys() {
  local rendered="$1" expected="$2" actual count expected_count
  actual="$(printf '%s\n' "$rendered" | extract_passkeys)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected passkey environment:\n%s\nExpected:\n%s\n' "$actual" "$expected" >&2
    return 1
  fi
  count="$(printf '%s\n' "$rendered" | awk '/- name: PASSKEY_/ { count++ } END { print count+0 }')"
  expected_count="$(printf '%s\n' "$expected" | awk 'NF { count++ } END { print count+0 }')"
  if [[ "$count" != "$expected_count" ]]; then
    echo "Passkey variables leaked outside the expected Deployment or were duplicated" >&2
    return 1
  fi
}

extract_feature() {
  awk '
    /^---/ { deployment=0; name=""; flag=0 }
    /^kind: Deployment$/ { deployment=1 }
    deployment && /^  name:/ { name=$2 }
    deployment && /- name: FEATURE_PASSKEYS_ENABLED$/ { flag=1; next }
    flag && /value:/ {
      value=$0
      sub(/^[[:space:]]*value: /, "", value)
      print name, value
      flag=0
    }
  ' | sort
}

assert_feature() {
  local rendered="$1" expected="$2" actual
  actual="$(printf '%s\n' "$rendered" | extract_feature)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected FEATURE_PASSKEYS_ENABLED:\n%s\nExpected:\n%s\n' "$actual" "$expected" >&2
    return 1
  fi
}

CONFIGURED_FLAGS=(
  --set-json kerberoshub.api.passkeys.enabled=true
  --set-json 'kerberoshub.api.passkeys.rpId="example.com"'
  --set-json 'kerberoshub.api.passkeys.origins=["https://hub.example.com","https://legacy.example.com:8443"]'
  --set-json 'kerberoshub.api.passkeys.rpName="Example Hub"'
)
expected="$(printf '%s\n' \
  'hub-api PASSKEY_ORIGINS "https://hub.example.com,https://legacy.example.com:8443"' \
  'hub-api PASSKEY_RP_ID "example.com"' \
  'hub-api PASSKEY_RP_NAME "Example Hub"' | sort)"

for mode in all ui pipeline; do
  default_render="$(helm template hub "$CHART_DIR" --set "mode=$mode")"
  assert_passkeys "$default_render" ""
  configured_render="$(helm template hub "$CHART_DIR" --set "mode=$mode" "${CONFIGURED_FLAGS[@]}")"
  if [[ "$mode" == pipeline ]]; then
    assert_passkeys "$configured_render" ""
    assert_feature "$default_render" ""
    assert_feature "$configured_render" ""
  else
    assert_passkeys "$configured_render" "$expected"
    assert_feature "$default_render" 'hub-frontend "false"'
    assert_feature "$configured_render" "$(printf '%s\n' 'hub-api "true"' 'hub-frontend "true"')"
  fi
  echo "OK ($mode): defaults opt out; enabled settings configure Hub API and flag the frontend"
done

disabled_render="$(helm template hub "$CHART_DIR" "${CONFIGURED_FLAGS[@]}" --set kerberoshub.api.passkeys.enabled=false)"
assert_passkeys "$disabled_render" ""
assert_feature "$disabled_render" 'hub-frontend "false"'

demo_render="$(helm template hub "$CHART_DIR" "${CONFIGURED_FLAGS[@]}" --set kerberoshub.frontend.demoEnabled=true)"
assert_feature "$demo_render" "$(printf '%s\n' 'hub-api "true"' 'hub-frontend "true"' 'hub-frontend-demo "true"')"

localhost_render="$(helm template hub "$CHART_DIR" --set mode=ui \
  --set kerberoshub.api.passkeys.enabled=true \
  --set-string kerberoshub.api.passkeys.rpId=localhost \
  --set-json 'kerberoshub.api.passkeys.origins=["http://localhost:4200"]')"
assert_passkeys "$localhost_render" "$(printf '%s\n' \
  'hub-api PASSKEY_ORIGINS "http://localhost:4200"' \
  'hub-api PASSKEY_RP_ID "localhost"' \
  'hub-api PASSKEY_RP_NAME "Kerberos Hub"' | sort)"

legacy_render="$(helm template hub "$CHART_DIR" --set mode=ui \
  --set-json 'kerberoshub.extraEnv=[{"name":"PASSKEY_RP_ID","value":"example.com"}]')"
printf '%s\n' "$legacy_render" | grep -q -- '- name: PASSKEY_RP_ID'

expect_invalid() {
  local output
  if output="$(helm template hub "$CHART_DIR" "${CONFIGURED_FLAGS[@]}" "$@" 2>&1)"; then
    echo "Invalid passkey settings unexpectedly rendered: $*" >&2
    return 1
  fi
  if [[ "$output" != *"passkeys"* ]]; then
    printf 'Rendering failed for an unexpected reason:\n%s\n' "$output" >&2
    return 1
  fi
}

expect_invalid --set-string kerberoshub.api.passkeys.rpId=
expect_invalid --set-json 'kerberoshub.api.passkeys.origins=[]'
expect_invalid --set-json 'kerberoshub.api.passkeys.origins=["https://hub.example.com/"]'
expect_invalid --set-json 'kerberoshub.api.passkeys.origins=["http://hub.example.com"]'
expect_invalid --set-json 'kerberoshub.api.passkeys.origins=["https://hub.example.com","https://hub.example.com"]'
expect_invalid --set-json 'kerberoshub.api.passkeys.origins="https://hub.example.com"'
expect_invalid --set-json 'kerberoshub.api.passkeys.enabled="true"'
expect_invalid --set-json 'kerberoshub.api.passkeys.rpId=123'
expect_invalid --set-json 'kerberoshub.api.passkeys.rpName=123'
expect_invalid --set-string kerberoshub.api.passkeys.origin=https://hub.example.com

echo "All Hub passkey configuration checks passed."
