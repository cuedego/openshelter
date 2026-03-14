# SLOs and SLIs

## Service Scope
OpenShelter critical paths:
- API and app workloads on EKS
- PostgreSQL data persistence on RDS
- MQTT messaging path
- Monitoring path through Zabbix API workflows

## Initial SLO Targets (MVP)
- API availability: 99.9% monthly
- MQTT broker availability: 99.9% monthly
- P95 API latency: < 400 ms monthly
- Critical alert MTTA: < 10 minutes
- Critical incident MTTR: < 60 minutes

## Initial SLIs
- Availability SLI: successful requests / total requests
- Latency SLI: p95 request duration
- Data SLI: successful DB connection ratio
- Alerting SLI: alert delivery success ratio

## Error Budget Policy
- Monthly error budget = 1 - SLO target
- If burn rate exceeds threshold for 24h:
  - Freeze non-critical changes
  - Prioritize reliability backlog
  - Require SRE approval for risky deployments

## Instrumentation Sources
- Kubernetes metrics and events
- Application-level HTTP and business metrics
- RDS health and connection metrics
- Zabbix event and trigger data

## Reporting
- Weekly reliability report in engineering sync
- Monthly SLO dashboard snapshot linked in PR notes for major releases
