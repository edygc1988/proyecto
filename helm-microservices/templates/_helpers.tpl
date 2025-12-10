{{/*
Nombre completo del chart
*/}}
{{- define "microservices.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Namespace - usa el namespace especificado o el del Release
*/}}
{{- define "microservices.namespace" -}}
{{- if .Values.namespace }}
{{- .Values.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Labels comunes
*/}}
{{- define "microservices.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels para microservice1
*/}}
{{- define "microservices.microservice1.selectorLabels" -}}
app: {{ .Values.microservice1.name }}
{{- end }}

{{/*
Selector labels para microservice2
*/}}
{{- define "microservices.microservice2.selectorLabels" -}}
app: {{ .Values.microservice2.name }}
{{- end }}

{{/*
Selector labels para postgres
*/}}
{{- define "microservices.postgres.selectorLabels" -}}
app: {{ .Values.postgres.name }}
{{- end }}
