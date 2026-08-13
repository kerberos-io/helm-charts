{{/*
Assemble the deployment-global workflow definitions (WORKFLOW_DEFINITIONS) as a
JSON array from every *enabled* workflow under kerberoshub.workflows.definitions.
This is the engine's boot-loaded configuration source and deployment stage
catalog: several distinct config workflows can run over one recording — each
opens its own run and dispatches only its own stages. Organisation-scoped
database workflows are discovered separately at runtime.

Each enabled definition contributes one workflow object:
  name      the map key (the workflow's human-readable name; also its identity —
            the engine derives a stable id from it when the definition carries
            no explicit id).
  enabled   always true here (a disabled definition is skipped entirely).
  source    "config" — provenance marking a Helm-defined, deployment-global,
            ops-managed workflow (read-only in the API, no owning organisation).
  triggers  how a run OPENS. Defaults to a single bare automatic trigger
            (opens for every recording); narrow with device/schedule triggers.
            Per-stage `needs` (below) decide which stages then FIRE.
  stages    the executable stage set, each contributing the same routing
            descriptor the stageRegistry emits:
              operation  the stage's operation (unique within the workflow).
              dispatch   "always" (default) | "conditional".
              queue      from the matching services.<operation>.queue
                         (authoritative; omitted when unset so the engine
                         derives "kcloud-<operation>-queue.fifo").
              needs      conditional stages only: upstream dependencies, each
                         {operation?, condition?}, carried through verbatim.
              needsMode  conditional stages: "any" (default) | "all".
*/}}
{{- define "kerberoshub.workflows.workflowDefinitions" -}}
{{- $defs := list -}}
{{- $services := .Values.kerberoshub.services | default dict -}}
{{- range $name, $wf := .Values.kerberoshub.workflows.definitions -}}
{{- if $wf.enabled -}}
{{- $stages := list -}}
{{- range $stage := $wf.stages -}}
{{- $op := $stage.operation -}}
{{- $entry := dict "operation" $op "dispatch" (default "always" $stage.dispatch) -}}
{{- $service := index $services $op -}}
{{- if $service }}{{- with $service.queue }}{{- $_ := set $entry "queue" . -}}{{- end }}{{- end }}
{{- with $stage.needs }}{{- $_ := set $entry "needs" . -}}{{- end }}
{{- with $stage.needsMode }}{{- $_ := set $entry "needsMode" . -}}{{- end }}
{{- $stages = append $stages $entry -}}
{{- end -}}
{{- $def := dict "name" $name "enabled" true "source" "config" "triggers" (default (list (dict "type" "automatic")) $wf.triggers) "stages" $stages -}}
{{- $defs = append $defs $def -}}
{{- end -}}
{{- end -}}
{{- $defs | toJson -}}
{{- end -}}

{{/*
Expose the deployment's operation→queue catalog to API producers that seed
embedded WorkflowRuns. Unlike WORKFLOW_DEFINITIONS this includes services that
are enabled for internal flows but are absent from user-visible workflow
definitions. The workflows engine remains authoritative for dispatch; producers
use this only to embed the same queue on a synthetic stage.
*/}}
{{- define "kerberoshub.workflows.stageQueues" -}}
{{- $queues := dict -}}
{{- range $operation, $service := (.Values.kerberoshub.services | default dict) -}}
{{- with $service.queue -}}
{{- $_ := set $queues $operation . -}}
{{- end -}}
{{- end -}}
{{- $queues | toJson -}}
{{- end -}}
