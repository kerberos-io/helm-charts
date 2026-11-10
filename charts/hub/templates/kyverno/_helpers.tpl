{{- /*
Shared building blocks for the Kyverno policies in this folder.
Each policy lives in its own file (one ClusterPolicy per file); these helpers
hold only what every policy repeats.
*/ -}}

{{- /*
hub.kyverno.enabled: "true" when policy <name> should be rendered: image
verification is enabled, the policy itself is enabled, and the cluster serves
kyverno.io/v1 (Kyverno installed).
Usage: {{- if eq (include "hub.kyverno.enabled" (dict "root" . "policy" "hubApi")) "true" }}
*/ -}}
{{- define "hub.kyverno.enabled" -}}
{{- $iv := .root.Values.imageVerification | default dict -}}
{{- $policy := index ($iv.policies | default dict) .policy | default dict -}}
{{- if and $iv.enabled $policy.enabled (.root.Capabilities.APIVersions.Has "kyverno.io/v1") -}}
true
{{- end -}}
{{- end -}}

{{- /*
hub.kyverno.name: ClusterPolicy name, unique per release: <namespace>-<release>-<suffix>.
Usage: {{ include "hub.kyverno.name" (dict "root" . "suffix" "hub-api-signed-images") }}
*/ -}}
{{- define "hub.kyverno.name" -}}
{{- printf "%s-%s-%s" .root.Release.Namespace .root.Release.Name .suffix | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /*
hub.kyverno.labels: common labels for every policy.
*/ -}}
{{- define "hub.kyverno.labels" -}}
app.kubernetes.io/name: hub
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: kyverno-policy
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- /*
hub.kyverno.spec: policy-wide settings; a policy's own values override the
imageVerification defaults (validationFailureAction, failurePolicy).
*/ -}}
{{- define "hub.kyverno.spec" -}}
{{- $iv := .root.Values.imageVerification -}}
{{- $policy := index $iv.policies .policy -}}
{{- $action := $policy.validationFailureAction | default $iv.validationFailureAction -}}
{{- $failure := $policy.failurePolicy | default $iv.failurePolicy -}}
{{- if not (has $action (list "Audit" "Enforce")) -}}
{{- fail (printf "imageVerification.policies.%s.validationFailureAction must be Audit or Enforce" .policy) -}}
{{- end -}}
{{- if not (has $failure (list "Ignore" "Fail")) -}}
{{- fail (printf "imageVerification.policies.%s.failurePolicy must be Ignore or Fail" .policy) -}}
{{- end -}}
validationFailureAction: {{ $action }}
background: true
failurePolicy: {{ $failure }}
webhookTimeoutSeconds: {{ $iv.webhookTimeoutSeconds | default 30 }}
{{- end -}}

{{- /*
hub.kyverno.signedBy: keyless cosign attestor for an image released by the
UUG.AI release workflow for GitHub repository <githubOrganization>/<repository>.
The signer identity is shared by every UUG.AI repository; the repository claim
binds the signature to this image's repository.
Usage: {{- include "hub.kyverno.signedBy" (dict "root" . "repository" "hub-api") | nindent 12 }}
*/ -}}
{{- define "hub.kyverno.signedBy" -}}
{{- $iv := .root.Values.imageVerification -}}
- entries:
    - keyless:
        issuer: {{ $iv.issuer | quote }}
        subjectRegExp: {{ $iv.subjectRegExp | squote }}
        additionalExtensions:
          githubWorkflowRepository: {{ printf "%s/%s" $iv.githubOrganization .repository | quote }}
        rekor:
          url: {{ $iv.rekorUrl | quote }}
{{- end -}}
