{{/*
Expand the name of the connectors subchart.
*/}}
{{- define "connectors.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name for connectors.
*/}}
{{- define "connectors.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- printf "%s-connectors" .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-connectors" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "connectors.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels for connectors
*/}}
{{- define "connectors.labels" -}}
helm.sh/chart: {{ include "connectors.chart" . }}
{{ include "connectors.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: connectors
{{- end -}}

{{/*
Selector labels for connectors
*/}}
{{- define "connectors.selectorLabels" -}}
app.kubernetes.io/name: {{ include "connectors.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Kafka Connect REST URL from parent chart or global values
*/}}
{{- define "connectors.connectRestUrl" -}}
{{- if .Values.global.connect.restUrl -}}
{{- .Values.global.connect.restUrl -}}
{{- else -}}
{{- printf "http://%s-kafka-connect:%d" .Release.Name ((.Values.global.connect.port | default 8083) | int) -}}
{{- end -}}
{{- end -}}

{{/*
Service account name for connectors (inherited from parent)
*/}}
{{- define "connectors.serviceAccountName" -}}
{{- printf "%s-kafka-connect" .Release.Name -}}
{{- end -}}