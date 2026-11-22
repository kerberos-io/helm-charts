{{/*
organisations.mode: legacy keeps the deployment on owner account > sub
accounts > roles. Fail when an organisation feature is switched on, so a
values file never half-enables organisations; custom lets every flag apply.
*/}}
{{- define "hub.organisations.validate" -}}
{{- $organisations := .Values.organisations | default dict -}}
{{- $mode := $organisations.mode | default "legacy" -}}
{{- if not (has $mode (list "legacy" "custom")) -}}
{{- fail (printf "organisations.mode must be legacy or custom, got %q" $mode) -}}
{{- end -}}
{{- if eq $mode "legacy" -}}
{{- $plans := (.Values.subscriptions | default dict).plans | default dict -}}
{{- $api := (.Values.kerberoshub | default dict).api | default dict -}}
{{- $features := ((.Values.kerberoshub | default dict).frontend | default dict).features | default dict -}}
{{- $orgUI := $features.organisations | default dict -}}
{{- $projectUI := $features.projects | default dict -}}
{{- $flags := list
  (list "subscriptions.plans.enabled" $plans.enabled)
  (list "subscriptions.plans.newOrganisations" $plans.newOrganisations)
  (list "organisations.onboarding.enabled" ($organisations.onboarding | default dict).enabled)
  (list "kerberoshub.api.rbacOrganisations.enabled" ($api.rbacOrganisations | default dict).enabled)
  (list "kerberoshub.api.organisationDeletion.enabled" ($api.organisationDeletion | default dict).enabled)
  (list "kerberoshub.frontend.features.organisations.enabled" $orgUI.enabled)
  (list "kerberoshub.frontend.features.organisations.switcherEnabled" $orgUI.switcherEnabled)
  (list "kerberoshub.frontend.features.organisations.creationEnabled" $orgUI.creationEnabled)
  (list "kerberoshub.frontend.features.organisations.settingsEnabled" $orgUI.settingsEnabled)
  (list "kerberoshub.frontend.features.organisations.membersAccessPreviewEnabled" $orgUI.membersAccessPreviewEnabled)
  (list "kerberoshub.frontend.features.projects.enabled" $projectUI.enabled)
  (list "kerberoshub.frontend.features.projects.switcherEnabled" $projectUI.switcherEnabled)
  (list "kerberoshub.frontend.features.projects.creationEnabled" $projectUI.creationEnabled)
  (list "kerberoshub.frontend.features.projects.settingsEnabled" $projectUI.settingsEnabled)
-}}
{{- $on := list -}}
{{- range $flags -}}
{{- if eq (index . 1 | toString | lower) "true" -}}
{{- $on = append $on (index . 0) -}}
{{- end -}}
{{- end -}}
{{- range ((.Values.kerberoshub | default dict).extraEnv | default list) -}}
{{- if and (eq (.name | toString) "ONBOARDING_ENABLED") (eq (.value | toString | lower) "true") -}}
{{- $on = append $on "kerberoshub.extraEnv ONBOARDING_ENABLED" -}}
{{- end -}}
{{- end -}}
{{- if $on -}}
{{- fail (printf "organisations.mode is legacy, but these organisation features are on: %s. Switch them off, or set organisations.mode: custom." (join ", " $on)) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Comma-separated names in kerberoshub.extraEnv: chart-set variables they name are left out, so extraEnv keeps winning without duplicates. */}}
{{- define "hub.extraEnv.names" -}}
{{- $names := list -}}
{{- range ((.Values.kerberoshub | default dict).extraEnv | default list) -}}
{{- $names = append $names (.name | toString) -}}
{{- end -}}
{{- join "," $names -}}
{{- end -}}
