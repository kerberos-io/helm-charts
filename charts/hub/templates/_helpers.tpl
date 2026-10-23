{{/* Build the path to the configured MongoDB CA bundle. */}}
{{- define "hub.mongodb.tlsCAFile" -}}
{{- if and .Values.mongodb.tls.enabled .Values.mongodb.tls.existingSecret .Values.mongodb.tls.caFileName -}}
{{- printf "%s/%s" .Values.mongodb.tls.mountPath .Values.mongodb.tls.caFileName | clean -}}
{{- end -}}
{{- end -}}

{{/* Add TLS options to a configured MongoDB URI unless they are already present. */}}
{{- define "hub.mongodb.uri" -}}
{{- $uri := .Values.mongodb.uri | default "" -}}
{{- if and .Values.mongodb.tls.enabled $uri -}}
  {{- if not (regexMatch "(?i)(^|[?&])tls=" $uri) -}}
    {{- $separator := "?" -}}
    {{- if contains "?" $uri -}}
      {{- $separator = "&" -}}
    {{- end -}}
    {{- if or (hasSuffix "?" $uri) (hasSuffix "&" $uri) -}}
      {{- $separator = "" -}}
    {{- end -}}
    {{- $uri = printf "%s%stls=true" $uri $separator -}}
  {{- end -}}
  {{- $caFile := include "hub.mongodb.tlsCAFile" . -}}
  {{- if and $caFile (not (regexMatch "(?i)(^|[?&])tlsCAFile=" $uri)) -}}
    {{- $separator := "&" -}}
    {{- if not (contains "?" $uri) -}}
      {{- $separator = "?" -}}
    {{- else if or (hasSuffix "?" $uri) (hasSuffix "&" $uri) -}}
      {{- $separator = "" -}}
    {{- end -}}
    {{- $uri = printf "%s%stlsCAFile=%s" $uri $separator $caFile -}}
  {{- end -}}
{{- end -}}
{{- $uri -}}
{{- end -}}

{{/*
MongoDB URI with appName set to one workload, so the Atlas query profiler and
currentOp attribute each operation to the service that issued it. Renders
nothing when no URI is configured or mongodb.appNamePerService is false.
Usage: include "hub.mongodb.appUri" (dict "root" $ "app" "hub-api")
*/}}
{{- define "hub.mongodb.appUri" -}}
{{- $uri := include "hub.mongodb.uri" .root -}}
{{- if and $uri .root.Values.mongodb.appNamePerService -}}
  {{- if regexMatch "(?i)[?&]appName=" $uri -}}
    {{- $uri = regexReplaceAll "(?i)([?&])appName=[^&]*" $uri (printf "${1}appName=%s" .app) -}}
  {{- else -}}
    {{- $separator := "&" -}}
    {{- if not (contains "?" $uri) -}}
      {{- $separator = "?" -}}
    {{- else if or (hasSuffix "?" $uri) (hasSuffix "&" $uri) -}}
      {{- $separator = "" -}}
    {{- end -}}
    {{- $uri = printf "%s%sappName=%s" $uri $separator .app -}}
  {{- end -}}
  {{- $uri -}}
{{- end -}}
{{- end -}}

{{/*
Container env entry that overrides MONGODB_URI from mongodb-config with the
workload's own appName. An explicit env entry takes precedence over envFrom.
Usage: {{- include "hub.mongodb.appUriEnv" (dict "root" $ "app" "hub-api") | nindent 12 }}
*/}}
{{- define "hub.mongodb.appUriEnv" -}}
{{- with include "hub.mongodb.appUri" . -}}
- name: MONGODB_URI
  value: {{ . | quote }}
{{- end -}}
{{- end -}}

{{/* Render the shared MongoDB CA Secret volume. */}}
{{- define "hub.mongodb.tlsVolume" -}}
- name: mongodb-tls
  secret:
    secretName: {{ .Values.mongodb.tls.existingSecret }}
{{- end -}}

{{/* Render the shared MongoDB CA volume mount. */}}
{{- define "hub.mongodb.tlsVolumeMount" -}}
- name: mongodb-tls
  mountPath: {{ .Values.mongodb.tls.mountPath }}
  readOnly: true
{{- end -}}

{{/*
OpenTelemetry sampling env.
"hub.opentelemetry.samplerEnv" is for the services that only continue traces
started elsewhere (hub-workflows, pipe-*, workflow stages): they follow the
parent's sampling decision and never start traces of their own.
"hub.opentelemetry.apiSamplerEnv" renders hub-api's per-class sampling ratios
(opentelemetry.apiSamplingRatios) as TRACE_SAMPLER_RATIO_<CLASS>; empty values
are not rendered.
Usage: {{- include "hub.opentelemetry.samplerEnv" $ | trim | nindent 8 }}
*/}}
{{- define "hub.opentelemetry.samplerEnv" -}}
- name: OTEL_TRACES_SAMPLER
  value: "parentbased_always_off"
{{- end -}}

{{- define "hub.opentelemetry.apiSamplerEnv" -}}
{{- range $class, $ratio := (.Values.opentelemetry.apiSamplingRatios | default dict) }}
{{- if ne (toString $ratio) "" }}
- name: TRACE_SAMPLER_RATIO_{{ upper $class }}
  value: {{ toString $ratio | quote }}
{{- end }}
{{- end }}
{{- end -}}
