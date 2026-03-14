# Access Control Policy

## Scope
Covers AWS, Kubernetes, GitHub, and operational tooling access.

## Rules
- Enforce least privilege for all identities
- Separate human and machine identities
- Use role-based access control (RBAC) in Kubernetes
- Require MFA for human access to production systems
- Review privileged access at least quarterly

## Environment Boundaries
- `dev`: broad access for experimentation, still auditable
- `stg`: restricted access for release validation
- `prod`: strict access, break-glass process required for emergency elevation

## Change Management
- Access changes require PR or tracked ticket
- Emergency access must be time-bounded and post-reviewed
