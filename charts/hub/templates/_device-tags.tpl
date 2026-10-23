{{/*
The system tag catalog (deviceTags.system.catalog) uses the Hub shared choice
catalog format: {key, label, description?}. values.schema.json validates each
entry (key in stored device tag form, models.NormalizeDeviceTags: 1-64
characters of a-z, 0-9, ".", "_", ":" and "-", starting and ending with a
letter or digit) and that enabled is a boolean; keys must also be unique.
*/}}
{{- define "kerberoshub.deviceTags.system.validate" -}}
{{- $seen := dict -}}
{{- range $tag := (include "kerberoshub.deviceTags.system.catalog" . | fromJsonArray) -}}
{{- $key := toString $tag.key -}}
{{- if hasKey $seen $key -}}
{{- fail (printf "deviceTags.system.catalog: duplicate key %q" $key) -}}
{{- end -}}
{{- $_ := set $seen $key true -}}
{{- end -}}
{{- end -}}

{{/*
The configured system tag catalog as a JSON array, whether or not system tags
are enabled (missing values read as empty).
*/}}
{{- define "kerberoshub.deviceTags.system.catalog" -}}
{{- $deviceTags := .Values.deviceTags | default dict -}}
{{- $system := $deviceTags.system | default dict -}}
{{- $system.catalog | default list | toJson -}}
{{- end -}}

{{/*
Whether system tags are enabled (deviceTags.system.enabled): "true" or "".
*/}}
{{- define "kerberoshub.deviceTags.system.enabled" -}}
{{- $deviceTags := .Values.deviceTags | default dict -}}
{{- $system := $deviceTags.system | default dict -}}
{{- if and (kindIs "bool" $system.enabled) $system.enabled -}}true{{- end -}}
{{- end -}}

{{/*
The system tag catalog file hub-api reads (DEVICE_SYSTEM_TAGS_FILE), rendered
from deviceTags.system.catalog into the device-system-tags ConfigMap.
*/}}
{{- define "kerberoshub.deviceTags.system.json" -}}
{{- include "kerberoshub.deviceTags.system.validate" . -}}
{{- $tags := list -}}
{{- range $tag := (include "kerberoshub.deviceTags.system.catalog" . | fromJsonArray) -}}
{{- $entry := dict "key" $tag.key "label" $tag.label -}}
{{- with $tag.description }}{{- $_ := set $entry "description" . -}}{{- end }}
{{- $tags = append $tags $entry -}}
{{- end -}}
{{- $tags | toJson -}}
{{- end -}}
