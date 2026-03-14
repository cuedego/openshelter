# ADRs (Architecture Decision Records)

This directory stores architecture decisions for OpenShelter.

## Why ADRs
ADRs preserve decision context, alternatives, and trade-offs so teams can understand why architecture choices were made.

## Naming Convention
- `NNNN-short-title.md`
- Example: `0001-repository-architecture-baseline.md`

## Lifecycle Status
- `Proposed`: under discussion
- `Accepted`: approved and active
- `Superseded`: replaced by a newer ADR
- `Deprecated`: no longer recommended

## Authoring Process
1. Copy `0000-template.md` into a new numbered file.
2. Fill all sections, especially alternatives and consequences.
3. Open a pull request and request review from relevant owners.
4. Update status after decision is approved.

## When to Create a New ADR
- Changes to centralized configuration model (`config/global.env`, `config/env/*`).
- Changes to Terraform state strategy (backend layout, locking model, key structure).
- Changes to GitOps reconciliation model (ArgoCD app topology, environment promotion flow).
- Changes to secrets delivery model (External Secrets Operator, AWS Secrets Manager integration).

## Practical Rule
If a change affects more than one platform layer (Terraform, CI/CD, GitOps, bootstrap scripts), create or update an ADR in the same PR.

## Initial ADRs
- `0001-repository-architecture-baseline.md`
- `0002-secrets-management-strategy.md`
- `0003-gitops-deployment-model.md`
