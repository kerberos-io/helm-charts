{{- define "hub.workflowConfiguration.bundledPaths" -}}
{{- list "workflow-contracts/start.yaml" "workflow-contracts/anpr.yaml" "workflow-contracts/forwarder.yaml" "catalogs/classifications.json" | toYaml -}}
{{- end -}}

{{- define "hub.workflowConfiguration.anpr.configMapName" -}}
{{- printf "%s-workflow-contract-anpr" (.Release.Name | trunc 40 | trimSuffix "-") -}}
{{- end -}}

{{- define "hub.workflowConfiguration.forwarder.configMapName" -}}
{{- printf "%s-workflow-contract-forwarder" (.Release.Name | trunc 40 | trimSuffix "-") -}}
{{- end -}}

{{- define "hub.classificationCatalog.configMapName" -}}
{{- $config := include "hub.workflowConfiguration.settings" . | fromYaml -}}
{{- $replacement := index $config.replacements "catalogs/classifications.json" | default dict -}}
{{- if $replacement -}}
{{- $replacement.name -}}
{{- else -}}
{{- default "classification-catalog" .Values.classificationCatalogExistingConfigMap -}}
{{- end -}}
{{- end -}}

{{/* Normalize both interfaces without changing the caller's values. */}}
{{- define "hub.workflowConfiguration.settings" -}}
{{- if hasKey .Values "classificationCatalog" -}}
{{- fail "classificationCatalog is no longer supported; remove the values key and place the complete catalog in a ConfigMap, then use workflowConfiguration.configMaps with path: catalogs/classifications.json and replace: true" -}}
{{- end -}}
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
{{- $enabled := $config.enabled | default false -}}
{{- $replacements := dict -}}
{{- $normalizedSources := list -}}
{{- $bundledPaths := include "hub.workflowConfiguration.bundledPaths" . | fromYamlArray -}}
{{- range $sources -}}
{{- $name := .name -}}
{{- $items := list -}}
{{- range .items -}}
{{- if and $enabled .replace -}}
{{- if or (not $unified) (not $includeDefaults) -}}
{{- fail "workflowConfiguration item replace: true requires configMaps with includeDefaults: true" -}}
{{- end -}}
{{- if not (has .path $bundledPaths) -}}
{{- fail (printf "workflowConfiguration item replace: true targets unknown bundled path %q" .path) -}}
{{- end -}}
{{- if hasKey $replacements .path -}}
{{- fail (printf "duplicate workflowConfiguration replacement path %q" .path) -}}
{{- end -}}
{{- $_ := set $replacements .path (dict "name" $name "key" .key) -}}
{{- end -}}
{{- $items = append $items (omit . "replace") -}}
{{- end -}}
{{- $normalizedSources = append $normalizedSources (dict "name" $name "items" $items) -}}
{{- end -}}
{{- if hasKey $replacements "catalogs/classifications.json" -}}
{{- if .Values.classificationCatalogExistingConfigMap -}}
{{- fail "a classifications.json replacement cannot be combined with classificationCatalogExistingConfigMap; choose one override mechanism" -}}
{{- end -}}
{{- end -}}
{{- dict "enabled" $enabled "includeDefaults" $includeDefaults "configMaps" $normalizedSources "replacements" $replacements | toYaml -}}
{{- end -}}

{{- define "hub.workflowConfiguration.validate" -}}
{{- $config := include "hub.workflowConfiguration.settings" . | fromYaml -}}
{{- if $config.enabled -}}
{{- $paths := dict -}}
{{- if $config.includeDefaults -}}
{{- if not .Values.classificationCatalogEnabled -}}
{{- fail "bundled workflowConfiguration requires classificationCatalogEnabled; disable includeDefaults and supply configMaps for a custom bundle" -}}
{{- end -}}
{{- range $path := (include "hub.workflowConfiguration.bundledPaths" . | fromYamlArray) -}}
{{- if not (hasKey $config.replacements $path) -}}
{{- $_ := set $paths $path true -}}
{{- end -}}
{{- end -}}
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
