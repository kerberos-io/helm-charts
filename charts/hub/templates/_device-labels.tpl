{{/*
Validate the deployment's device label catalog (root deviceLabels): a list of
{value, name?, description?}. value uses the stored device label form
(models.NormalizeDeviceLabels): 1-64 characters of a-z, 0-9, ".", "_", ":"
and "-", starting and ending with a letter or digit. Values are unique.
*/}}
{{- define "kerberoshub.deviceLabels.validate" -}}
{{- $seen := dict -}}
{{- range $i, $label := (.Values.deviceLabels | default list) -}}
{{- if not (kindIs "map" $label) -}}
{{- fail (printf "deviceLabels[%d] must be an object with a value" $i) -}}
{{- end -}}
{{- $value := $label.value -}}
{{- if or (not (kindIs "string" $value)) (gt (len (toString $value)) 64) (not (regexMatch "^[a-z0-9]([a-z0-9._:-]*[a-z0-9])?$" (toString $value))) -}}
{{- fail (printf "deviceLabels[%d].value %q must be 1-64 characters of a-z, 0-9, '.', '_', ':' or '-', starting and ending with a letter or digit" $i (toString $value)) -}}
{{- end -}}
{{- if hasKey $seen $value -}}
{{- fail (printf "deviceLabels: duplicate value %q" $value) -}}
{{- end -}}
{{- $_ := set $seen $value true -}}
{{- range $field := list "name" "description" -}}
{{- if and (hasKey $label $field) (not (kindIs "string" (index $label $field))) -}}
{{- fail (printf "deviceLabels[%d].%s must be a string" $i $field) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The device label catalog as JSON (DEVICE_LABELS on hub-api): each entry with
its value, a name (defaulting to the value) and an optional description. Empty
while deviceLabelsEnabled is false, which disables labels in hub-api.
*/}}
{{- define "kerberoshub.deviceLabels.json" -}}
{{- include "kerberoshub.deviceLabels.validate" . -}}
{{- $labels := list -}}
{{- if .Values.deviceLabelsEnabled -}}
{{- range $label := (.Values.deviceLabels | default list) -}}
{{- $entry := dict "value" $label.value "name" (default $label.value $label.name) -}}
{{- with $label.description }}{{- $_ := set $entry "description" . -}}{{- end }}
{{- $labels = append $labels $entry -}}
{{- end -}}
{{- end -}}
{{- $labels | toJson -}}
{{- end -}}
