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

{{/*
hub.audit.destinations resolves the audit destinations into JSON. Inline
credentials (s3.accessKey / s3.secretKey on S3 destinations, bearerToken and
secretHeaders.<name>.value on webhooks) are turned into a chart-created Secret named
hub-audit-<id>-credentials, so every template below reads one shape:
credentialsSecret / bearerTokenSecret / secretHeaders with create: true and the
values to store.
Use: fromJsonArray (include "hub.audit.destinations" .)
*/}}
{{- define "hub.audit.destinations" -}}
{{- $resolved := list -}}
{{- range $index, $original := .Values.kerberoshub.audit.destinations -}}
  {{- $destination := deepCopy $original -}}
  {{- $s3 := default dict $destination.s3 -}}
  {{- if or (hasKey $s3 "accessKey") (hasKey $s3 "secretKey") -}}
    {{- $id := required (printf "id is required for audit destination %d" $index) $destination.id -}}
    {{- if not (and $s3.accessKey $s3.secretKey) -}}
      {{- fail (printf "audit destination %s must set both s3.accessKey and s3.secretKey, and neither may be empty" $id) -}}
    {{- end -}}
    {{- if $destination.credentialsSecret -}}
      {{- fail (printf "audit destination %s sets s3.accessKey/secretKey and credentialsSecret; use one of them" $id) -}}
    {{- end -}}
    {{- $_ := set $destination "credentialsSecret" (dict
        "name" (printf "hub-audit-%s-credentials" $id)
        "create" true
        "accessKeyId" $s3.accessKey
        "secretAccessKey" $s3.secretKey) -}}
    {{- $_ := unset $s3 "accessKey" -}}
    {{- $_ := unset $s3 "secretKey" -}}
  {{- end -}}
  {{- if hasKey $destination "bearerToken" -}}
    {{- $id := required (printf "id is required for audit destination %d" $index) $destination.id -}}
    {{- if not $destination.bearerToken -}}
      {{- fail (printf "audit destination %s sets an empty bearerToken" $id) -}}
    {{- end -}}
    {{- if $destination.bearerTokenSecret -}}
      {{- fail (printf "audit destination %s sets bearerToken and bearerTokenSecret; use one of them" $id) -}}
    {{- end -}}
    {{- $_ := set $destination "bearerTokenSecret" (dict
        "name" (printf "hub-audit-%s-credentials" $id)
        "key" "bearer-token"
        "create" true
        "value" $destination.bearerToken) -}}
    {{- $_ := unset $destination "bearerToken" -}}
  {{- end -}}
  {{- range $header, $secret := (default dict $destination.secretHeaders) -}}
    {{- if and (kindIs "map" $secret) (hasKey $secret "value") -}}
      {{- $id := required (printf "id is required for audit destination %d" $index) $destination.id -}}
      {{- if not $secret.value -}}
        {{- fail (printf "audit destination %s header %s sets an empty value" $id $header) -}}
      {{- end -}}
      {{- if or $secret.secretName $secret.secretKey -}}
        {{- fail (printf "audit destination %s header %s sets value and secretName/secretKey; use one of them" $id $header) -}}
      {{- end -}}
      {{- $_ := set $secret "secretName" (printf "hub-audit-%s-credentials" $id) -}}
      {{- $_ := set $secret "secretKey" (printf "header-%s" (sha256sum $header | trunc 12)) -}}
      {{- $_ := set $secret "create" true -}}
    {{- end -}}
  {{- end -}}
  {{- $resolved = append $resolved $destination -}}
{{- end -}}
{{- toJson $resolved -}}
{{- end -}}
