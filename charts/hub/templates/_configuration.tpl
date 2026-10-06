{{- define "hub.classificationCatalog.configMapName" -}}
{{- default "classification-catalog" .Values.classificationCatalogExistingConfigMap -}}
{{- end -}}

{{/* Keep the legacy endpoint and the preparatory bundle on the same chart data. */}}
{{- define "hub.classificationCatalog" -}}
{{- if kindIs "invalid" .Values.classificationCatalog -}}
{{- .Files.Get "configuration/catalogs/classifications.json" | mustFromJson | toPrettyJson -}}
{{- else if kindIs "slice" .Values.classificationCatalog -}}
{{- .Values.classificationCatalog | toPrettyJson -}}
{{- else -}}
{{- fail "classificationCatalog must be null (bundled defaults) or a list" -}}
{{- end -}}
{{- end -}}

{{/* Normalize both interfaces without changing the caller's values. */}}
{{- define "hub.workflowConfiguration.settings" -}}
{{- $config := .Values.workflowConfiguration | default dict -}}
{{- $unified := or (hasKey $config "includeDefaults") (hasKey $config "configMaps") -}}
{{- $legacy := or (hasKey $config "existingConfigMap") (hasKey $config "items") (hasKey $config "extraConfigMaps") -}}
{{- if and $unified $legacy -}}
{{- fail "workflowConfiguration cannot mix includeDefaults/configMaps with existingConfigMap/items/extraConfigMaps" -}}
{{- end -}}
{{- $includeDefaults := true -}}
{{- $sources := $config.extraConfigMaps | default list -}}
{{- if $unified -}}
{{- $sources = $config.configMaps | default list -}}
{{- if hasKey $config "includeDefaults" -}}
{{- $includeDefaults = $config.includeDefaults -}}
{{- end -}}
{{- else -}}
{{- if $config.existingConfigMap -}}
{{- if and $config.enabled (not $config.items) -}}
{{- fail "workflowConfiguration.items is required with existingConfigMap" -}}
{{- end -}}
{{- $includeDefaults = false -}}
{{- $sources = prepend $sources (dict "name" $config.existingConfigMap "items" ($config.items | default list)) -}}
{{- else if and $config.enabled $config.items -}}
{{- fail "workflowConfiguration.items requires existingConfigMap" -}}
{{- end -}}
{{- end -}}
{{- dict "enabled" ($config.enabled | default false) "includeDefaults" $includeDefaults "configMaps" $sources | toYaml -}}
{{- end -}}

{{- define "hub.workflowConfiguration.validate" -}}
{{- $config := include "hub.workflowConfiguration.settings" . | fromYaml -}}
{{- if $config.enabled -}}
{{- $paths := dict -}}
{{- if $config.includeDefaults -}}
{{- if not .Values.classificationCatalogEnabled -}}
{{- fail "bundled workflowConfiguration requires classificationCatalogEnabled; disable includeDefaults and supply configMaps for a custom bundle" -}}
{{- end -}}
{{- $_ := set $paths "workflow-contracts/start.yaml" true -}}
{{- $_ := set $paths "catalogs/classifications.json" true -}}
{{- else -}}
{{- if not $config.configMaps -}}
{{- fail "workflowConfiguration.configMaps must be nonempty when enabled without defaults" -}}
{{- end -}}
{{- end -}}
{{- range $config.configMaps -}}
{{- if not .items -}}
{{- fail (printf "workflowConfiguration ConfigMap %q requires nonempty items" .name) -}}
{{- end -}}
{{- range .items -}}
{{- if not (regexMatch "^[A-Za-z0-9._-]+$" .key) -}}
{{- fail "workflowConfiguration.items keys must be valid ConfigMap keys" -}}
{{- end -}}
{{- if or (not (regexMatch "^(workflow-contracts|catalogs)/[A-Za-z0-9_-][A-Za-z0-9._-]*\\.(yaml|json)$" .path)) (ne (clean .path) .path) -}}
{{- fail "workflowConfiguration.items paths must be normalized relative files under workflow-contracts/ or catalogs/" -}}
{{- end -}}
{{- if hasKey $paths .path -}}
{{- fail (printf "duplicate workflowConfiguration.items path %q" .path) -}}
{{- end -}}
{{- $_ := set $paths .path true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
