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

{{- define "hub.workflowConfiguration.validate" -}}
{{- $config := .Values.workflowConfiguration | default dict -}}
{{- if $config.enabled -}}
{{- $paths := dict -}}
{{- $sources := $config.extraConfigMaps | default list -}}
{{- if $config.existingConfigMap -}}
{{- if not $config.items -}}
{{- fail "workflowConfiguration.items is required with existingConfigMap" -}}
{{- end -}}
{{- $sources = prepend $sources (dict "name" $config.existingConfigMap "items" $config.items) -}}
{{- else -}}
{{- if $config.items -}}
{{- fail "workflowConfiguration.items requires existingConfigMap" -}}
{{- end -}}
{{- if not .Values.classificationCatalogEnabled -}}
{{- fail "bundled workflowConfiguration requires classificationCatalogEnabled; use an existingConfigMap for a custom bundle" -}}
{{- end -}}
{{- $_ := set $paths "workflow-contracts/start.yaml" true -}}
{{- $_ := set $paths "catalogs/classifications.json" true -}}
{{- end -}}
{{- range $sources -}}
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
