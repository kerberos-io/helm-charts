#!/usr/bin/env bash
# Chart-only checks; no cluster or application loader required.
set -euo pipefail

CHART_DIR="${1:-charts/hub}"

assert_contains() {
  if ! grep -Fq -- "$2" <<<"$1"; then
    printf 'FAIL: expected rendered output to contain %s\n' "$2" >&2
    exit 1
  fi
}

assert_absent() {
  if grep -Fq -- "$2" <<<"$1"; then
    printf 'FAIL: unexpected rendered output contains %s\n' "$2" >&2
    exit 1
  fi
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output="$(helm template hub "$CHART_DIR" "$@" 2>&1)"; then
    printf 'FAIL: render unexpectedly succeeded: %s\n' "$*" >&2
    exit 1
  fi
  assert_contains "$output" "$expected"
}

if grep -q '^classificationCatalog:' "$CHART_DIR/values.yaml"; then
  echo "FAIL: classificationCatalog should be omitted from default values" >&2
  exit 1
fi
default_out="$(helm template hub "$CHART_DIR")"
assert_absent "$default_out" "name: workflow-configuration"
assert_absent "$default_out" "checksum/workflow-configuration"
assert_contains "$default_out" "value: /etc/kerberos/classifications/classifications.json"
legacy_out="$(helm template hub "$CHART_DIR" --set workflowConfiguration=null)"
if [ "$default_out" != "$legacy_out" ]; then
  echo "FAIL: absent workflowConfiguration changed the default render" >&2
  exit 1
fi

null_out="$(helm template hub "$CHART_DIR" --set classificationCatalog=null)"
if [ "$default_out" != "$null_out" ]; then
  echo "FAIL: omitted and null classificationCatalog render differently" >&2
  exit 1
fi

# A file-backed default must render identically to the previous inline-list form.
explicit_out="$(helm template hub "$CHART_DIR" \
  --set-json "classificationCatalog=$(tr -d '\n' <"$CHART_DIR/configuration/catalogs/classifications.json")")"
if [ "$default_out" != "$explicit_out" ]; then
  echo "FAIL: bundled defaults and explicit classification list render differently" >&2
  exit 1
fi

override_flags=(--set-json 'classificationCatalog=[{"key":"forklift","label":"Forklift","icon":"vehicle"}]')
override_out="$(helm template hub "$CHART_DIR" "${override_flags[@]}")"
assert_contains "$override_out" '"key": "forklift"'
assert_absent "$override_out" '"key": "pedestrian"'

empty_out="$(helm template hub "$CHART_DIR" --set-json 'classificationCatalog=[]')"
assert_contains "$empty_out" "    []"
assert_absent "$empty_out" '"key": "pedestrian"'
disabled_out="$(helm template hub "$CHART_DIR" --set classificationCatalogEnabled=false)"
assert_absent "$disabled_out" "name: classification-catalog"
assert_absent "$disabled_out" "CLASSIFICATION_CATALOG_FILE"

bundle_out="$(helm template hub "$CHART_DIR" --set workflowConfiguration.enabled=true)"
assert_contains "$bundle_out" "checksum/workflow-configuration:"
assert_contains "$bundle_out" "mountPath: /etc/kerberos/configuration"
assert_contains "$bundle_out" "path: workflow-contracts/start.yaml"
assert_contains "$bundle_out" "path: catalogs/classifications.json"
assert_contains "$bundle_out" "source: project.devices"
assert_contains "$bundle_out" "file: ../catalogs/classifications.json"
assert_absent "$bundle_out" "WORKFLOW_CONTRACTS"
bundle_config="$(helm template hub "$CHART_DIR" --set workflowConfiguration.enabled=true \
  --show-only templates/configmap-workflow-configuration.yaml)"
assert_absent "$bundle_config" "classifications.json: |-"
override_bundle="$(helm template hub "$CHART_DIR" --set workflowConfiguration.enabled=true "${override_flags[@]}")"
assert_contains "$override_bundle" '"key": "forklift"'
assert_absent "$override_bundle" '"key": "pedestrian"'

external_flags=(-f "$CHART_DIR/examples/workflow-configuration-values.yaml")
external_out="$(helm template hub "$CHART_DIR" "${external_flags[@]}")"
assert_contains "$external_out" 'name: "custom-workflow-contracts"'
assert_contains "$external_out" 'name: "shared-pose-catalog"'
assert_contains "$external_out" "path: workflow-contracts/pose.yaml"
assert_contains "$external_out" "path: catalogs/pose-keypoints.json"
assert_contains "$external_out" "path: workflow-contracts/start.yaml"
assert_contains "$external_out" "path: catalogs/classifications.json"
assert_contains "$external_out" "name: hub-workflow-configuration"
assert_contains "$external_out" "checksum/workflow-configuration"
external_override="$(helm template hub "$CHART_DIR" "${external_flags[@]}" "${override_flags[@]}")"
assert_contains "$external_override" '"key": "forklift"'
assert_absent "$external_override" '"key": "pedestrian"'
external_disabled="$(helm template hub "$CHART_DIR" "${external_flags[@]}" --set workflowConfiguration.enabled=false)"
if [ "$default_out" != "$external_disabled" ]; then
  echo "FAIL: disabled configuration rendered custom ConfigMaps" >&2
  exit 1
fi

# Preserve the published full-replacement option without making it the default.
replacement_flags=(
  --set workflowConfiguration.enabled=true
  --set workflowConfiguration.existingConfigMap=legacy-workflow-configuration
  --set-json 'workflowConfiguration.items=[{"key":"legacy.yaml","path":"workflow-contracts/legacy.yaml"}]'
)
replacement_out="$(helm template hub "$CHART_DIR" "${replacement_flags[@]}" --set classificationCatalogEnabled=false)"
assert_contains "$replacement_out" 'name: "legacy-workflow-configuration"'
assert_contains "$replacement_out" "path: workflow-contracts/legacy.yaml"
assert_absent "$replacement_out" "name: hub-workflow-configuration"
assert_absent "$replacement_out" "checksum/workflow-configuration"
replacement_extra="$(helm template hub "$CHART_DIR" "${replacement_flags[@]}" "${external_flags[@]}")"
assert_contains "$replacement_extra" "path: workflow-contracts/legacy.yaml"
assert_contains "$replacement_extra" "path: workflow-contracts/pose.yaml"

ui_out="$(helm template hub "$CHART_DIR" --set mode=ui --set workflowConfiguration.enabled=true)"
assert_contains "$ui_out" "name: hub-workflow-configuration"
pipeline_out="$(helm template hub "$CHART_DIR" --set mode=pipeline --set workflowConfiguration.enabled=true)"
assert_absent "$pipeline_out" "name: hub-workflow-configuration"
assert_absent "$pipeline_out" "name: workflow-configuration"

expect_failure "requires classificationCatalogEnabled" \
  --set workflowConfiguration.enabled=true --set classificationCatalogEnabled=false
expect_failure "items is required" \
  --set workflowConfiguration.enabled=true --set workflowConfiguration.existingConfigMap=custom
expect_failure "items requires existingConfigMap" "${replacement_flags[@]}" --set workflowConfiguration.existingConfigMap=
expect_failure "duplicate workflowConfiguration.items path" "${replacement_flags[@]}" "${external_flags[@]}" \
  --set 'workflowConfiguration.items[0].path=workflow-contracts/pose.yaml'
for duplicate in workflow-contracts/start.yaml catalogs/classifications.json catalogs/pose-keypoints.json; do
  expect_failure "duplicate workflowConfiguration.items path" "${external_flags[@]}" \
    --set "workflowConfiguration.extraConfigMaps[0].items[0].path=$duplicate"
done
expect_failure "duplicate workflowConfiguration.items path" "${external_flags[@]}" \
  --set-json 'workflowConfiguration.extraConfigMaps[0].items=[{"key":"a","path":"workflow-contracts/pose.yaml"},{"key":"b","path":"workflow-contracts/pose.yaml"}]'
for invalid_path in ../../secret.yaml /etc/secret.yaml catalogs/../secret.json; do
  expect_failure "workflowConfiguration" "${external_flags[@]}" \
    --set "workflowConfiguration.extraConfigMaps[0].items[0].path=$invalid_path"
done
expect_failure "workflowConfiguration" "${external_flags[@]}" \
  --set-json 'workflowConfiguration.extraConfigMaps[0].items=[]'
expect_failure "workflowConfiguration" "${external_flags[@]}" \
  --set 'workflowConfiguration.extraConfigMaps[0].name=INVALID_NAME'
expect_failure "classificationCatalog" --set classificationCatalog=not-a-list

echo "All workflow configuration and classification catalog checks passed."
