{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 53 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 53 chars (63 - len("-discovery")) because some Kubernetes name fields are limited to 63 (by the DNS naming spec).
*/}}
{{- define "fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 53 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of btcd.
*/}}
{{- define "btcd.fullname" -}}
{{- printf "%s-%s" (include "fullname" .) "btcd" | trunc 53 | trimSuffix "-" -}}
{{- end }}

{{/*
Expand the name of alice lnd node.
*/}}
{{- define "alice.fullname" -}}
{{- printf "%s-%s" (include "fullname" .) "alice" | trunc 53 | trimSuffix "-" -}}
{{- end }}

{{/*
Expand the name of bob lnd node.
*/}}
{{- define "bob.fullname" -}}
{{- printf "%s-%s" (include "fullname" .) "bob" | trunc 53 | trimSuffix "-" -}}
{{- end }}

{{/*
Expand the name of the debugger pod.
*/}}
{{- define "debugger.fullname" -}}
{{- printf "%s-%s" (include "fullname" .) "debugger" | trunc 53 | trimSuffix "-" -}}
{{- end }}

{{/*
Expand the name of the prometheus pod.
*/}}
{{- define "prometheus.fullname" -}}
{{- printf "%s-%s" (include "fullname" .) "prometheus" | trunc 53 | trimSuffix "-" -}}
{{- end }}

{{/*
Expand the name of the grafana pod.
*/}}
{{- define "grafana.fullname" -}}
{{- printf "%s-%s" (include "fullname" .) "grafana" | trunc 53 | trimSuffix "-" -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "lnd-stack.labels" -}}
helm.sh/chart: {{ include "lnd-stack.chart" . }}
{{ include "lnd-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lnd-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lnd-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lnd-stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lnd-stack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
