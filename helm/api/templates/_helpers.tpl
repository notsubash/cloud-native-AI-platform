{{/*
Expand chart name. Used in labels.
*/}}
{{- define "api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fullname: release name + chart name, truncated to DNS-safe 63 chars.
helm install my-api ./helm/api  →  often "my-api" or "my-api-api"
*/}}
{{- define "api.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels — useful for kubectl get all -l app.kubernetes.io/instance=...
*/}}
{{- define "api.labels" -}}
helm.sh/chart: {{ include "api.chart" . }}
{{ include "api.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels — MUST be identical on Deployment selector, Pod template, and Service selector
*/}}
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret name used by the Deployment for DEEPSEEK_API_KEY (and optional DB keys)
*/}}
{{- define "api.secretName" -}}
{{- if .Values.secret.create }}
{{- include "api.fullname" . }}
{{- else }}
{{- required "existingSecret is required when secret.create is false" .Values.existingSecret }}
{{- end }}
{{- end }}