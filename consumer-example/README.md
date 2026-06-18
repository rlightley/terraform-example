# Consumer Repository — Setup Guide

This directory is a reference implementation for a team repository that consumes the `terraform-factory`. Copy this structure into a new repository to get started.

The consumer repository contains **no Terraform code**. All infrastructure logic lives in the factory. The consumer provides:
- `config.json` — all environment configuration (workload, SKUs, regions, backend details)
- `.github/workflows/deploy.yml` — calls the factory's reusable pipeline
- `custom/` *(optional)* — any additional Terraform resources not covered by the factory

---

## Repository Structure

```
.
├── config.json                           # All configuration — the only file you need to edit
├── .checkov.yml                          # Checkov scan overrides
├── custom/                               # Optional: extra Terraform resources
│   ├── landing-zone/                     # .tf files merged into the landing-zone stage
│   └── application/                      # .tf files merged into the application stage
└── .github/
    └── workflows/
        └── deploy.yml                    # Thin pipeline that calls the factory
```

---

## Prerequisites

### 1. Azure State Backend

Create the storage account that Terraform will use to store state before the first deployment:

```bash
az group create --name rg-terraform-state --location uksouth

az storage account create \
  --name stmyapptfstate \
  --resource-group rg-terraform-state \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name stmyapptfstate
```

### 2. Azure Service Principal with OIDC

Create a Service Principal and configure federated credentials for passwordless authentication from GitHub Actions:

```bash
SP=$(az ad sp create-for-rbac --name "sp-myapp-terraform" --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID --output json)

CLIENT_ID=$(echo $SP | jq -r '.appId')

az ad app federated-credential create --id "$CLIENT_ID" --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id "$CLIENT_ID" --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:YOUR_ORG/YOUR_REPO:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

az role assignment create \
  --assignee "$CLIENT_ID" \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/stmyapptfstate
```

### 3. GitHub Repository Secrets

Add these under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service Principal Application (Client) ID |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |
| `FACTORY_READ_TOKEN` | PAT with `repo:read` on the factory (required if factory is private) |

### 4. GitHub Environments

The pipeline requires GitHub Environments with required reviewer approval before any `terraform apply`. Create these under **Settings → Environments**:

| Environment Name | Suggested reviewers | Notes |
|-----------------|-------------------|-------|
| `dev-apply` | Optional | Fast iteration in dev |
| `staging-apply` | 1 reviewer | Mandatory approval |
| `prod-apply` | 2 reviewers | Mandatory approval + deployment branch restriction to `main` |

---

## Configuration Reference (`config.json`)

All values the factory needs come from a single `config.json`. The file has four top-level fields (`workload`, `environment`, `location`, `location_short`) plus three sections (`backend`, `landing_zone`, `application`):

### Top-level fields

| Field | Description |
|-------|-------------|
| `workload` | Short workload name used to build all resource names (e.g. `myapp`) |
| `environment` | Deployment environment: `dev`, `staging`, or `prod`. Determines the GitHub approval environment (`{environment}-apply`). |
| `location` | Azure region for all resources (e.g. `uksouth`) |
| `location_short` | Short region code appended to every resource name (e.g. `uks`, `euw`) |

All four fields are automatically injected into every stage — do not repeat `workload`, `location`, or `location_short` inside the `landing_zone` or `application` sections.

Resource names are derived by the factory using the pattern `{prefix}-{workload}-{environment}-{location_short}`. You never supply individual resource names.

### `backend` section

Configures the Azure Storage Account used for Terraform remote state. The factory reads this at runtime — no `backend.hcl` file needed.

| Field | Description |
|-------|-------------|
| `resource_group_name` | Resource group containing the state storage account |
| `storage_account_name` | Storage account name |
| `container_name` | Blob container name |
| `landing_zone_state_key` | State file name for the landing zone stage |
| `application_state_key` | State file name for the application stage |

### `landing_zone` section

Networking, Key Vault, and logging configuration. See the [Landing Zone module docs](../README.md#landing-zone-module) for the full variable reference.

Do not include `workload`, `environment`, `location`, or `location_short` — these are injected automatically from the top-level fields. Do not include resource names — all names are derived by the factory.

### `application` section

SKU, runtime stack, and SQL admin configuration. See the [Application module docs](../README.md#application-module) for the full variable reference.

The following are resolved automatically and must **not** be in this section:
- `workload`, `environment`, `location`, `location_short` — injected from top level
- `resource_group_name`, `vnet_integration_subnet_id`, `log_analytics_workspace_id`, `key_vault_id` — resolved from landing zone remote state
- All resource names — derived by the factory
- `sql_aad_admin_object_id` — resolved automatically from `sql_aad_admin_login` via an `azuread_group` data source

Use `vnet_integration_subnet_name` to specify which subnet from the landing zone the App Service should integrate with (default: `snet-app`).

---

## Multiple Environments

For multiple environments, use separate config files and pass the path at dispatch time:

```
config.dev.json
config.staging.json
config.prod.json
```

Trigger with:

```bash
gh workflow run deploy.yml -f config_path=config.prod.json
```

Or configure separate branches/workflows per environment with the config file path hardcoded in `deploy.yml`.

---

## Adding Custom Resources

To deploy resources not covered by the factory modules, add Terraform files to the `custom/` directory:

```
custom/
  landing-zone/
    storage-account.tf    # Extra resources deployed as part of the landing-zone stage
  application/
    service-bus.tf        # Extra resources deployed as part of the application stage
```

The factory pipeline automatically merges these files into the stage working directory before running Checkov and `terraform plan`. Custom files can reference module outputs via the root module outputs:

```hcl
resource "azurerm_storage_account" "extra" {
  name                = "st${var.workload}extra${var.location_short}"
  resource_group_name = module.landing_zone.resource_group_name
  location            = var.location
  ...
}
```

---

## Updating the Factory Version

When the factory publishes a new release, update both references in `deploy.yml`:

```yaml
uses: YOUR_ORG/terraform-factory/.github/workflows/reusable-terraform.yml@v1.1.0
with:
  factory_ref: v1.1.0
```

Always test version upgrades in `dev` before promoting to `staging` and `prod`. Check the factory [CHANGELOG](../CHANGELOG.md) for breaking changes.
