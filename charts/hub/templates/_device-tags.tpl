{{/*
Validate the deployment's system tag catalog (deviceTags.system.catalog): a
list of {value, name?, description?}. value uses the stored device tag form
(models.NormalizeDeviceTags): 1-64 characters of a-z, 0-9, ".", "_", ":" and
"-", starting and ending with a letter or digit. Values are unique.
*/}}
{{- define "kerberoshub.deviceTags.system.validate" -}}
{{- $seen := dict -}}
{{- range $i, $tag := (include "kerberoshub.deviceTags.system.catalog" . | fromJsonArray) -}}
{{- if not (kindIs "map" $tag) -}}
{{- fail (printf "deviceTags.system.catalog[%d] must be an object with a value" $i) -}}
{{- end -}}
{{- $value := $tag.value -}}
{{- if or (not (kindIs "string" $value)) (gt (len (toString $value)) 64) (not (regexMatch "^[a-z0-9]([a-z0-9._:-]*[a-z0-9])?$" (toString $value))) -}}
{{- fail (printf "deviceTags.system.catalog[%d].value %q must be 1-64 characters of a-z, 0-9, '.', '_', ':' or '-', starting and ending with a letter or digit" $i (toString $value)) -}}
{{- end -}}
{{- if hasKey $seen $value -}}
{{- fail (printf "deviceTags.system.catalog: duplicate value %q" $value) -}}
{{- end -}}
{{- $_ := set $seen $value true -}}
{{- range $field := list "name" "description" -}}
{{- if and (hasKey $tag $field) (not (kindIs "string" (index $tag $field))) -}}
{{- fail (printf "deviceTags.system.catalog[%d].%s must be a string" $i $field) -}}
{{- end -}}
{{- end -}}
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
{{- if $system.enabled -}}true{{- end -}}
{{- end -}}

{{/*
The system tag catalog as JSON (DEVICE_SYSTEM_TAGS on hub-api): each entry
with its value, a name (defaulting to the value) and an optional description.
Empty while deviceTags.system.enabled is false, which disables system tags in
hub-api.
*/}}
{{- define "kerberoshub.deviceTags.system.json" -}}
{{- include "kerberoshub.deviceTags.system.validate" . -}}
{{- $tags := list -}}
{{- if include "kerberoshub.deviceTags.system.enabled" . -}}
{{- range $tag := (include "kerberoshub.deviceTags.system.catalog" . | fromJsonArray) -}}
{{- $entry := dict "value" $tag.value "name" (default $tag.value $tag.name) -}}
{{- with $tag.description }}{{- $_ := set $entry "description" . -}}{{- end }}
{{- $tags = append $tags $entry -}}
{{- end -}}
{{- end -}}
{{- $tags | toJson -}}
{{- end -}}
