# Workflow Patterns Explained

## Pattern: Plan-on-PR, Deploy-on-Merge

This is the core pattern of the workshop. It mirrors how code review works, but for infrastructure:

```
Developer makes IaC change
        │
        ▼
Opens Pull Request ──→ Workflow runs Plan/What-If
        │                       │
        │               ┌───────▼───────┐
        │               │ PR Comment:   │
        │               │ "Will create  │
        │               │  3 resources, │
        │               │  modify 1"    │
        │               └───────────────┘
        │
Reviewer reads PR + Plan output
        │
        ▼
Approves and merges ──→ Workflow runs Deploy/Apply
                                │
                        ┌───────▼───────┐
                        │  Resources    │
                        │  deployed     │
                        │  in Azure     │
                        └───────────────┘
```

### Why This Matters

Without this pattern, you discover what your IaC will do AFTER it runs. That means broken infrastructure, unexpected costs, or accidental deletion of production resources. The Plan-on-PR pattern shifts that discovery to code review time.

## Pattern: Path-Filtered Triggers

Each workflow uses `paths` filters to only trigger when relevant files change:

```yaml
on:
  push:
    branches: [main]
    paths: ["infra/bicep/**"]     # Only Bicep changes trigger this
```

This prevents the Bicep workflow from running when you change Terraform files and vice versa. It also means application code changes (`src/`) only trigger the build workflow, not the infrastructure workflows.

## Pattern: Workflow Dispatch for Manual Control

Every workflow includes `workflow_dispatch` which adds a "Run workflow" button in the Actions tab:

```yaml
on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options:
          - plan
          - apply
          - destroy
```

This serves two purposes:
1. **Workshop**: Participants can trigger workflows manually to understand each step
2. **Operations**: Teams can run ad-hoc plans or destroy environments without pushing code

## Pattern: Environment Protection Rules

The deploy/apply jobs declare `environment: production`:

```yaml
deploy:
  environment: production
  # ...
```

This does three things:
1. Requires approval from designated reviewers before the job executes
2. Uses the environment-specific OIDC federated credential
3. Creates an audit log of who approved each deployment

## Pattern: Artifact Passing (Terraform)

The Terraform workflow uploads the plan as an artifact and downloads it in the apply job:

```
Plan Job                          Apply Job
   │                                 │
   ├── terraform plan -out=tfplan    │
   ├── upload-artifact (tfplan)      │
   │                                 │
   │         ┌───────────────────────┤
   │         │                       │
   │         │    download-artifact  ├──
   │         │    terraform apply    ├──
   │         │         tfplan        │
```

This guarantees that what was approved in the plan is exactly what gets applied. Without this, a new commit between plan and apply could change the outcome.

## Pattern: Concurrency Locks (Terraform)

```yaml
concurrency:
  group: terraform-deploy
  cancel-in-progress: false
```

Terraform state supports one writer at a time. The concurrency setting queues parallel runs instead of running them simultaneously (which would cause state lock errors) or cancelling them (which could leave state in a bad place).

## Pattern: Bicep Default, Terraform Opt-In

The workshop enables Bicep workflows by default because:
- No state backend to configure
- No additional tooling to install
- Simpler operational model for Azure-only deployments

Terraform triggers are commented out and can be enabled by the participant. This design lets beginners focus on the workflow pattern without the overhead of state management, while giving advanced users the full Terraform experience.
