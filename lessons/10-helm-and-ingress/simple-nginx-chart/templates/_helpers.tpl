{{- define "simple-nginx-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "simple-nginx-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "simple-nginx-chart.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
