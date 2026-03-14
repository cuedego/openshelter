{{/*
Common labels applied to every resource.
*/}}
{{- define "openshelter.labels" -}}
app.kubernetes.io/part-of: openshelter-stack
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels for the Zabbix server Deployment.
*/}}
{{- define "openshelter.zabbix.selectorLabels" -}}
app.kubernetes.io/name: openshelter-zabbix
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for the MQTT Deployment.
*/}}
{{- define "openshelter.mqtt.selectorLabels" -}}
app.kubernetes.io/name: openshelter-mqtt
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
