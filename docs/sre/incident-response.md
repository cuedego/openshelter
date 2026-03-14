# Incident Response

## Severity Levels
- SEV1: Customer-facing outage or major data risk
- SEV2: Partial degradation with significant impact
- SEV3: Minor degradation with workaround available
- SEV4: Low-risk issue with no immediate customer impact

## Roles
- Incident Commander (IC): coordinates response and priorities
- Communications Lead: updates stakeholders and status
- Operations Lead: executes mitigations
- Subject Matter Expert: supports root-cause analysis

## Response Workflow
1. Detect and acknowledge alert
2. Classify severity and open incident channel
3. Stabilize service (mitigation first)
4. Communicate updates every 15-30 minutes (SEV1/SEV2)
5. Recover, validate, and close incident
6. Start postmortem within 48 hours for SEV1/SEV2

## Escalation
- Auto-escalate to on-call SRE after 10 minutes unacknowledged
- Escalate to Platform lead for infra-impacting SEV1/SEV2
- Escalate to Security lead for suspected security incidents

## Postmortem Requirements
- Timeline with UTC timestamps
- Root cause and contributing factors
- Corrective and preventive actions with owners and due dates
- Follow-up tracking in backlog with status visibility
