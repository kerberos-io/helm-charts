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
secretHeaders.<name>.value on webhooks) are the only way to pass credentials.
They are stored in a chart-created Secret named hub-audit-<id>-credentials;
the internal credentialsSecret / bearerTokenSecret / secretHeaders entries
below describe that Secret for the other templates.
Use: fromJsonArray (include "hub.audit.destinations" .)
*/}}
{{- define "hub.audit.destinations" -}}
{{- $resolved := list -}}
{{- range $index, $original := .Values.kerberoshub.audit.destinations -}}
  {{- $destination := deepCopy $original -}}
  {{- $label := default (printf "%d" $index) $destination.id -}}
  {{- if hasKey $destination "credentialsSecret" -}}
    {{- fail (printf "audit destination %s: credentialsSecret is not supported; set s3.accessKey and s3.secretKey" $label) -}}
  {{- end -}}
  {{- if hasKey $destination "bearerTokenSecret" -}}
    {{- fail (printf "audit destination %s: bearerTokenSecret is not supported; set bearerToken" $label) -}}
  {{- end -}}
  {{- $s3 := default dict $destination.s3 -}}
  {{- if or (hasKey $s3 "accessKey") (hasKey $s3 "secretKey") -}}
    {{- $id := required (printf "id is required for audit destination %d" $index) $destination.id -}}
    {{- if not (and $s3.accessKey $s3.secretKey) -}}
      {{- fail (printf "audit destination %s must set both s3.accessKey and s3.secretKey, and neither may be empty" $id) -}}
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
    {{- $_ := set $destination "bearerTokenSecret" (dict
        "name" (printf "hub-audit-%s-credentials" $id)
        "key" "bearer-token"
        "create" true
        "value" $destination.bearerToken) -}}
    {{- $_ := unset $destination "bearerToken" -}}
  {{- end -}}
  {{- range $header, $secret := (default dict $destination.secretHeaders) -}}
    {{- if or (not (kindIs "map" $secret)) (not (hasKey $secret "value")) (hasKey $secret "secretName") (hasKey $secret "secretKey") -}}
      {{- fail (printf "audit destination %s header %s: set secretHeaders.%s.value" $label $header $header) -}}
    {{- end -}}
    {{- $id := required (printf "id is required for audit destination %d" $index) $destination.id -}}
    {{- if not $secret.value -}}
      {{- fail (printf "audit destination %s header %s sets an empty value" $id $header) -}}
    {{- end -}}
    {{- $_ := set $secret "secretName" (printf "hub-audit-%s-credentials" $id) -}}
    {{- $_ := set $secret "secretKey" (printf "header-%s" (sha256sum $header | trunc 12)) -}}
    {{- $_ := set $secret "create" true -}}
  {{- end -}}
  {{- $resolved = append $resolved $destination -}}
{{- end -}}
{{- toJson $resolved -}}
{{- end -}}

{{/*
Extra container env for a pipeline service, from <component>.extraEnv: a list
of Kubernetes EnvVar entries (name + value, or name + valueFrom), rendered after
every variable the chart sets. Use it for worker settings the chart has no
value for yet.

Do not repeat a variable the chart already sets: Kubernetes keeps the last
entry, but server-side apply (Argo CD ServerSideApply) can reject a duplicate
name. Names repeated within extraEnv itself fail the render.

Usage, as the last line of the container's env list:
  {{- include "hub.pipeline.extraEnv" (dict "path" "kerberospipeline.thumbnail" "values" $.Values.kerberospipeline.thumbnail) }}
*/}}
{{- define "hub.pipeline.extraEnv" -}}
{{- $env := (.values | default dict).extraEnv | default list -}}
{{- $seen := dict -}}
{{- range $i, $var := $env -}}
  {{- if not (and (kindIs "map" $var) $var.name) -}}
    {{- fail (printf "%s.extraEnv[%d] needs a name" $.path $i) -}}
  {{- end -}}
  {{- if hasKey $seen $var.name -}}
    {{- fail (printf "%s.extraEnv sets %s more than once" $.path $var.name) -}}
  {{- end -}}
  {{- $_ := set $seen $var.name true -}}
{{- end -}}
{{- with $env }}
{{ toYaml . | indent 8 }}
{{- end -}}
{{- end -}}

{{/*
hub-frontend scratch volume.
The hardened hub-frontend image runs with a read-only root filesystem and
writes its generated runtime configuration (/tmp/frontend-env.js) and nginx's
PID/temp files to /tmp, so every frontend pod needs a writable /tmp. The chart
always renders a memory-backed emptyDir for it, so custom branding or
translation mounts in kerberoshub.frontend.volumes / volumeMounts only add to
the pod and can never drop it (Helm replaces lists, it does not merge them).
Deployments that still list the old frontend-tmp entries themselves, or mount
their own volume at /tmp, keep those: the built-in entries are skipped.
*/}}
{{- define "hub.frontend.hasTmpMount" -}}
{{- range .Values.kerberoshub.frontend.volumeMounts }}{{ if eq .mountPath "/tmp" }}true{{ end }}{{ end }}
{{- end -}}

{{- define "hub.frontend.hasTmpVolume" -}}
{{- range .Values.kerberoshub.frontend.volumes }}{{ if eq .name "frontend-tmp" }}true{{ end }}{{ end }}
{{- end -}}

{{- define "hub.frontend.volumes" -}}
{{- $tmp := .Values.kerberoshub.frontend.tmp | default dict }}
{{- if not (or (include "hub.frontend.hasTmpMount" .) (include "hub.frontend.hasTmpVolume" .)) }}
- name: frontend-tmp
  emptyDir:
    medium: Memory
    sizeLimit: {{ $tmp.sizeLimit | default "16Mi" }}
{{- end }}
{{- with .Values.kerberoshub.frontend.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "hub.frontend.volumeMounts" -}}
{{- if not (include "hub.frontend.hasTmpMount" .) }}
- name: frontend-tmp
  mountPath: /tmp
{{- end }}
{{- with .Values.kerberoshub.frontend.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end -}}
