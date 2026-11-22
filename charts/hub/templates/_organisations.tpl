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
{{- /*
The same features set directly in kerberoshub.extraEnv (hub-api and the
frontend). Booleans count when true as hub-api parses them; PLANS_FILE
counts when set. A valueFrom cannot be read here, so it counts as on.
*/ -}}
{{- $booleanEnv := list
  "PLANS_NEW_ORGANISATIONS" "ONBOARDING_ENABLED" "RBAC_ORGANISATIONS_ENABLED"
  "FEATURE_ORGANISATION_DELETION_ENABLED"
  "FEATURE_ORGANISATIONS_ENABLED" "FEATURE_ORGANISATION_SWITCHER_ENABLED"
  "FEATURE_ORGANISATION_CREATION_ENABLED" "FEATURE_ORGANISATION_SETTINGS_ENABLED"
  "FEATURE_MEMBERS_ACCESS_PREVIEW_ENABLED"
  "FEATURE_PROJECTS_ENABLED" "FEATURE_PROJECT_SWITCHER_ENABLED"
  "FEATURE_PROJECT_CREATION_ENABLED" "FEATURE_PROJECT_SETTINGS_ENABLED"
-}}
{{- range ((.Values.kerberoshub | default dict).extraEnv | default list) -}}
{{- $name := .name | default "" | toString -}}
{{- $value := .value | default "" | toString | trim | lower -}}
{{- $label := printf "kerberoshub.extraEnv %s" $name -}}
{{- if or (eq $name "PLANS_FILE") (has $name $booleanEnv) -}}
{{- if .valueFrom -}}
{{- $on = append $on (printf "%s (valueFrom)" $label) -}}
{{- else if and (eq $name "PLANS_FILE") $value -}}
{{- $on = append $on $label -}}
{{- else if and (has $name $booleanEnv) (has $value (list "true" "1" "t")) -}}
{{- $on = append $on $label -}}
{{- end -}}
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
