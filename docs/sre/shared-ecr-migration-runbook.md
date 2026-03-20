# Shared ECR Migration Runbook

## Objective
Move ECR ownership out of environment stacks (`dev`, `stg`, `prod`) into the shared Terraform stack (`platform/terraform/shared`) so environment lifecycle no longer impacts ECR.

## Preconditions
- AWS credentials configured with permissions for Terraform and ECR.
- `config/global.env` and `config/local.env` are valid.
- No concurrent Terraform apply running for shared or environment stacks.

## Execution Order
1. Render generated config files:
   - `make render-config`
2. Initialize shared stack backend:
   - `terraform -chdir=platform/terraform/shared init -input=false -backend-config=backend.hcl`
3. Import existing ECR repositories into shared state:
   - `terraform -chdir=platform/terraform/shared import 'module.ecr.aws_ecr_repository.this["openshelter/zabbix"]' openshelter/zabbix`
   - `terraform -chdir=platform/terraform/shared import 'module.ecr.aws_ecr_repository.this["openshelter/mqtt"]' openshelter/mqtt`
4. Apply shared stack:
   - `terraform -chdir=platform/terraform/shared apply -input=false -var="region=<aws-region>"`
5. Apply environment stacks normally (`dev`, `stg`, `prod`):
   - Existing `removed` blocks detach old ECR resources from environment state with `destroy=false`.

## Validation
- `terraform -chdir=platform/terraform/shared plan -var="region=<aws-region>"` returns no unexpected changes.
- `terraform -chdir=platform/terraform/envs/dev plan` has no ECR create/destroy actions.
- Same validation for `stg` and `prod`.

## Rollback
If migration is interrupted before environment stacks are reconciled:
- Keep shared stack as source of truth and re-run environment apply.
- Do not re-add ECR module to environment stacks.
- If needed, re-import repositories in shared and re-run apply.
