{{/*
Assemble the workflows engine stage registry (PIPELINE_STAGE_REGISTRY) as a
JSON array from every *enabled* stage under kerberoshub.workflows.stages, so the
engine's routing stays in lockstep with the deployed stage workers and the
per-stage queue cannot drift. The `stages:` block is the routing source of truth;
each stage's deployment (and its queue) lives under the matching
kerberoshub.services.<name> entry.

Each enabled stage contributes one descriptor:
  operation  defaults to the stage's map key.
  dispatch   defaults to "always".
  queue      taken from the matching services.<key>.queue (authoritative; the
             same value the worker consumes via <NAME>_QUEUE). Omitted when the
             service or its queue is unset, so the engine derives
             "kcloud-<operation>-queue.fifo".
  needs      conditional stages only: the upstream dependencies (each
             {operation, condition?}) carried through verbatim.
*/}}
{{- define "kerberoshub.workflows.stageRegistry" -}}
{{- $entries := list -}}
{{- $services := .Values.kerberoshub.services | default dict -}}
{{- range $name, $stage := .Values.kerberoshub.workflows.stages -}}
{{- if $stage.enabled -}}
{{- $entry := dict "operation" (default $name $stage.operation) "dispatch" (default "always" $stage.dispatch) -}}
{{- $service := index $services $name -}}
{{- if $service }}{{- with $service.queue }}{{- $_ := set $entry "queue" . -}}{{- end }}{{- end }}
{{- with $stage.needs }}{{- $_ := set $entry "needs" . -}}{{- end }}
{{- $entries = append $entries $entry -}}
{{- end -}}
{{- end -}}
{{- $entries | toJson -}}
{{- end -}}
