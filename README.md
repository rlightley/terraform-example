# Terraform Factory

This repository is a **centralised Terraform factory** for deploying a lightweight Azure landing zone and application stack. Teams do not clone or fork this repo — instead they create their own consumer repositories that contain only a `config.json` and a thin pipeline. The factory handles all Terraform code, security scanning, state management, and the approval-gated pipeline.

---

## Table of Contents

- [How It Works](#how-it-works)
- [Repository Structure](#repository-structure)
- [Modules](#modules)
  - [Landing Zone](#landing-zone-module)
  - [Application](#application-module)
- [Stages](#stages)
- [Pipeline Architecture](#pipeline-architecture)
  - [Job Flow](#job-flow)
  - [Workspace Preparation](#workspace-preparation)
  - [Approval Gates](#approval-gates)
  - [Security Scanning](#security-scanning)
- [Versioning and Releases](#versioning-and-releases)
- [Creating a Consumer Repository](#creating-a-consumer-repository)
- [Contributing](#contributing)
- [Azure Best Practices](#azure-best-practices)

---

## How It Works

```
 ┌───────────────────────────────────────────────────┐
 │              terraform-factory (this repo)         │
 │                                                    │
 │   stages/landing-zone/    ◄── root TF configs      │
 │   stages/application/                              │
 │                                                    │
 │   modules/landing-zone/   ◄── reusable modules     │
 │   modules/application/                             │
 │                                                    │
 │   .github/workflows/reusable-terraform.yml         │
 └───────────────────────────────────────────────────┘
                   ▲                ▲
        workflow_call @tag     second checkout @tag
                   │                │
 ┌───────────────────────────────────────────────────┐
 │         consumer-repo (team creates this)          │
 │                                                    │
 │   config.json            ◄── only config needed    │
 │   custom/                ◄── optional extra .tf    │
 │   .github/workflows/deploy.yml                     │
 └───────────────────────────────────────────────────┘
```

**Deployment flow:**

1. Consumer triggers `deploy.yml`, passing a config file path
2. The factory's reusable workflow runs in the consumer's context
3. It checks out the factory repo (at the pinned `factory_ref` tag) alongside the consumer repo
4. It parses `config.json` to extract backend config and stage-specific variables
5. Any custom `.tf` files from `consumer/custom/{stage}/` are merged into the factory's stage directory
6. A `terraform.auto.tfvars.json` is generated from the config and placed in the stage workspace
7. Checkov runs security checks, then Terraform plans with the backend config injected as flags
8. A GitHub Environment protection rule gates the apply — a reviewer must approve before it runs

---

## Repository Structure

```
.
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md          # Conventional-commit PR template with Checkov table
│   └── workflows/
│       ├── versioning.yml                # Auto-tags and creates releases on merge to main
│       └── reusable-terraform.yml        # Called by consumer pipelines
├── stages/
│   ├── landing-zone/                     # Root module: calls modules/landing-zone
│   │   ├── main.tf
│   │   └── variables.tf
│   └── application/                      # Root module: calls modules/application via remote state
│       ├── main.tf
│       └── variables.tf
├── modules/
│   ├── landing-zone/                     # VNet, Key Vault, Log Analytics, RBAC
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── networking.tf
│   │   ├── keyvault.tf
│   │   ├── logging.tf
│   │   └── rbac.tf
│   └── application/                      # App Service, SQL, App Insights
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── app_service.tf
│       └── sql.tf
├── consumer-example/                     # Reference implementation for a consumer repo
│   ├── config.json                       # All configuration in one file
│   ├── .checkov.yml
│   └── .github/workflows/deploy.yml
├── .checkov.yml
├── CHANGELOG.md
└── README.md
```

---

## Modules

### Landing Zone Module

**Path:** `modules/landing-zone`

Deploys the foundational Azure infrastructure that the application layer depends on.

#### Resources Created

| Resource | Purpose |
|----------|---------|
| `azurerm_resource_group` | Container for all landing zone resources |
| `azurerm_virtual_network` | VNet with configurable address space |
| `azurerm_subnet` | One NSG-associated subnet per entry in `subnets` config |
| `azurerm_network_security_group` | Per-subnet NSG |
| `azurerm_key_vault` | RBAC-authorised Key Vault with soft delete and purge protection |
| `azurerm_log_analytics_workspace` | Centralised log workspace |
| `azurerm_monitor_diagnostic_setting` | Diagnostics → Log Analytics for VNet and Key Vault |
| `azurerm_role_assignment` | Configurable RBAC at resource group scope |
| `azurerm_resource_group_policy_assignment` | Optional: restrict deployments to allowed regions |

#### Inputs (`config.json` → `landing_zone` section)

| Key | Type | Default | Required | Description |
|-----|------|---------|----------|-------------|
| `resource_group_name` | string | — | Yes | Resource group name |
| `location` | string | — | Yes | Azure region |
| `vnet_name` | string | — | Yes | Virtual network name |
| `vnet_address_space` | list(string) | — | Yes | CIDR blocks |
| `subnets` | map | — | Yes | `{ name: { address_prefix, service_endpoints? } }` |
| `key_vault_name` | string | — | Yes | Globally unique (3–24 chars) |
| `key_vault_sku` | string | `"standard"` | No | `standard` or `premium` |
| `key_vault_network_default_action` | string | `"Allow"` | No | `Allow` or `Deny`. See [Key Vault Network Access](#key-vault-network-access) |
| `log_analytics_workspace_name` | string | — | Yes | Log Analytics workspace name |
| `log_analytics_sku` | string | `"PerGB2018"` | No | Billing SKU |
| `log_retention_days` | number | `30` | No | 30–730 |
| `role_assignments` | map | `{}` | No | `{ label: { principal_id, role_definition_name } }` |
| `allowed_locations` | list(string) | `[]` | No | Enforces allowed regions via Azure Policy. Empty = skip |
| `tags` | map(string) | `{}` | No | Applied to all resources |

`environment` is injected automatically from the top-level config field.

#### Outputs (available to `application` stage via remote state)

| Output | Description |
|--------|-------------|
| `resource_group_name` | Resource group name |
| `resource_group_id` | Resource group ID |
| `vnet_id` | VNet resource ID |
| `subnet_ids` | Map of `{ subnet_name → resource_id }` |
| `key_vault_id` | Key Vault resource ID |
| `key_vault_uri` | Key Vault URI |
| `log_analytics_workspace_id` | Log Analytics workspace resource ID |

---

### Application Module

**Path:** `modules/application`

Deploys the application stack. References the landing zone via Terraform remote state — no manual wiring needed.

#### Resources Created

| Resource | Purpose |
|----------|---------|
| `azurerm_service_plan` | App Service Plan (Linux) |
| `azurerm_linux_web_app` | App Service — HTTPS-only, TLS 1.2, VNet integration, system-assigned identity |
| `azurerm_application_insights` | Connected to Log Analytics workspace |
| `azurerm_monitor_diagnostic_setting` | HTTP and app logs → Log Analytics |
| `random_password` | Generated SQL administrator password |
| `azurerm_key_vault_secret` | SQL password stored as `sql-admin-password` in Key Vault |
| `azurerm_mssql_server` | TLS 1.2, Azure AD admin, public network access disabled |
| `azurerm_mssql_database` | SQL database |
| `azurerm_mssql_server_extended_auditing_policy` | Audit events → Log Analytics |

#### Inputs (`config.json` → `application` section)

| Key | Type | Default | Required | Description |
|-----|------|---------|----------|-------------|
| `location` | string | — | Yes | Azure region |
| `vnet_integration_subnet_name` | string | `"snet-app"` | No | Subnet name from the landing zone for App Service VNet integration |
| `app_service_plan_name` | string | — | Yes | App Service Plan name |
| `app_service_plan_sku_name` | string | `"B2"` | No | SKU name (e.g., `B1`, `S1`, `P1v3`) |
| `app_service_name` | string | — | Yes | App Service name (globally unique) |
| `app_stack` | object | `{}` | No | Runtime stack. Set one of: `dotnet_version`, `node_version`, `python_version`, `java_version` |
| `sql_server_name` | string | — | Yes | SQL Server name (globally unique) |
| `sql_database_name` | string | — | Yes | SQL database name |
| `sql_database_sku_name` | string | `"S1"` | No | Database SKU |
| `sql_aad_admin_login` | string | — | Yes | Azure AD group or user name for SQL administration |
| `sql_aad_admin_object_id` | string | — | Yes | Object ID of the Azure AD SQL administrator |
| `tags` | map(string) | `{}` | No | Applied to all resources |

`environment`, `resource_group_name`, `vnet_integration_subnet_id`, `log_analytics_workspace_id`, and `key_vault_id` are all resolved automatically — do not include them in the config.

---

## Stages

**Path:** `stages/`

Stages are the deployable root Terraform configurations. They are not called by consumers directly — the factory's reusable workflow checks out the factory repo and runs the appropriate stage using the consumer's `config.json` as its variable source.

| Stage | Directory | Description |
|-------|-----------|-------------|
| `landing-zone` | `stages/landing-zone/` | Wraps `modules/landing-zone`. Backend initialised from `config.backend`. |
| `application` | `stages/application/` | Wraps `modules/application`. Reads landing zone outputs via `data.terraform_remote_state`. Backend and state references injected from `config.backend`. |

---

## Pipeline Architecture

### Job Flow

Each stage runs four sequential jobs:

```
setup ──► security-scan ──► plan ──► apply
```

| Job | What it does |
|-----|-------------|
| `setup` | Checks out both consumer and factory repos. Parses `config.json`. Merges any consumer custom `.tf` files into the stage directory. Generates `terraform.auto.tfvars.json`. Packages the workspace as an artifact. |
| `security-scan` | Extracts workspace artifact. Runs Checkov. Uploads SARIF to GitHub Code Scanning. Fails the pipeline if any check fails. |
| `plan` | Extracts workspace artifact. Runs `terraform init` with backend config from `setup` outputs. Runs `terraform plan -detailed-exitcode`. Posts plan output to the workflow step summary. Uploads `tfplan` artifact if changes are present. |
| `apply` | Downloads workspace and `tfplan` artifacts. Targets the `{environment}-apply` GitHub Environment — **execution is blocked until a reviewer approves**. Runs `terraform apply` against the pre-built plan. |

### Workspace Preparation

The `setup` job builds a portable workspace that subsequent jobs reuse:

1. Factory stage `.tf` files (`stages/{stage}/`) form the base
2. Consumer custom files (`custom/{stage}/*.tf`) are merged in on top
3. `terraform.auto.tfvars.json` is generated from the relevant config section
4. For the `application` stage, backend fields are also injected so the remote state data source can initialise
5. The workspace is packaged as a `.tar.gz` artifact and downloaded by `security-scan`, `plan`, and `apply`

### Approval Gates

Human approval is enforced via **GitHub Environment protection rules** on the `apply` job. The apply job targets the environment `{environment}-apply` (read from `config.json`). Configure required reviewers on each environment in the consumer repository under **Settings → Environments**.

The `apply` job is skipped entirely if `terraform plan` exits with code `0` (no changes). The `tfplan` artifact is retained for **7 days** — if approval takes longer, re-run the pipeline.

### Security Scanning

[Checkov](https://www.checkov.io/) runs on every push and PR. Results are:

- Printed in the job log
- Uploaded as SARIF to GitHub Code Scanning (**Security → Code scanning**)
- Treated as a hard failure — the plan will not run if Checkov fails

The `.checkov.yml` in the consumer repo root configures skip checks for that repo. Additional skip checks can be passed per-stage via the `checkov_skip_checks` workflow input.

**Default skipped checks:**

| Check | Reason |
|-------|--------|
| `CKV_AZURE_109` | Key Vault network default action is intentionally configurable. Set to `Deny` with a VNet-integrated runner in production. |

---

## Versioning and Releases

Every merge to `main` automatically:

1. Parses commit messages since the last tag using [Conventional Commits](https://www.conventionalcommits.org/)
2. Bumps the version tag (`vMAJOR.MINOR.PATCH`)
3. Updates `CHANGELOG.md` and commits it (does not re-trigger versioning due to `paths-ignore`)
4. Creates a GitHub Release with auto-generated notes

### Commit Format

```
<type>[optional scope]: <description>
```

| Type | Version bump | Example |
|------|-------------|---------|
| `fix:` | Patch | `fix: correct subnet NSG association` |
| `feat:` | Minor | `feat: add private endpoint support` |
| `feat!:` / `BREAKING CHANGE:` | Major | `feat!: rename vnet_address_space variable` |
| `chore:`, `docs:`, `ci:` | Patch | `chore: update azurerm provider` |

### Pinning Versions in Consumer Repos

Consumer repos pin both the workflow call and the `factory_ref` to the same tag:

```yaml
uses: YOUR_ORG/terraform-factory/.github/workflows/reusable-terraform.yml@v1.2.0
with:
  factory_ref: v1.2.0
```

Check the [Releases](../../releases) page and `CHANGELOG.md` for breaking changes before upgrading.

---

## Creating a Consumer Repository

See the full setup guide in [consumer-example/README.md](./consumer-example/README.md).

**Quick summary:**

1. Create a new GitHub repository
2. Copy `consumer-example/config.json` and `consumer-example/.github/` into the repo root
3. Replace `YOUR_ORG/terraform-factory` with the actual org/repo in `deploy.yml`
4. Update both `@v1.0.0` references to the latest factory release tag
5. Update all values in `config.json` for your environment
6. Create the Azure state backend storage account
7. Create a Service Principal with OIDC federated credentials
8. Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (and `FACTORY_READ_TOKEN` if factory is private) as GitHub secrets
9. Create GitHub Environments `dev-apply`, `staging-apply`, `prod-apply` with required reviewers
10. Push to `main`

---

## Contributing

### Branch Strategy

All changes go through a pull request to `main`. Branch prefixes: `feat/`, `fix/`, `chore/`, `docs/`.

### PR Checklist

The PR template prompts for:
- Commit type (determines version bump)
- Affected modules
- Checkov findings table with justification for any skips
- Confirmation that variable additions have defaults (backwards compatible)

### Adding Resources to a Module

When adding new resources, ensure:
- Diagnostic settings route logs to the Log Analytics workspace
- Managed identities are used in preference to stored credentials
- TLS minimum version is set to 1.2 on all network-facing resources
- Key Vault RBAC roles are used (not legacy access policies)

---

## Azure Best Practices

| Practice | How it's enforced |
|----------|------------------|
| No stored credentials | SQL admin password generated by `random_password`, stored in Key Vault |
| Managed identity | App Service uses system-assigned managed identity |
| Azure AD SQL admin | Required — SQL Server has `azuread_administrator` block |
| TLS 1.2 minimum | Enforced on App Service and SQL Server |
| HTTPS-only | App Service `https_only = true` |
| Key Vault RBAC | `enable_rbac_authorization = true` (not legacy access policies) |
| Soft delete | 90-day retention |
| Purge protection | Enabled — Key Vault cannot be permanently deleted until retention expires |
| Centralised logging | All resources send diagnostics to the Log Analytics workspace |
| SQL auditing | Extended auditing policy enabled |

### Key Vault Network Access

`key_vault_network_default_action` defaults to `Allow` for compatibility with GitHub-hosted runners. For production, set this to `Deny` and use one of:

| Approach | Notes |
|----------|-------|
| Self-hosted runner inside the VNet | Most secure |
| GitHub-hosted runner with Azure VNET injection | Available on GitHub Team/Enterprise |

### SQL Server Connectivity

SQL Server is created with `public_network_access_enabled = false`. The SQL admin password is generated by Terraform and stored in Key Vault — it never appears in config files, logs, or state in plaintext.

For App Service to connect to the database at runtime, add a **private endpoint** for the SQL server and configure the private DNS zone `privatelink.database.windows.net`. This is not included in the base module to keep the example self-contained, but is strongly recommended for production workloads.

### SARIF Upload Permissions

Checkov SARIF upload to GitHub Code Scanning requires the workflow to have `security-events: write` permission. Configure this in the consumer repo under **Settings → Actions → General → Workflow permissions**.
