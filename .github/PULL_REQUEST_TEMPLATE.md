# Pull Request

## Type of Change

Select the type that best describes this PR. The commit type determines how the version is bumped when merged.

- [ ] `feat:` — New feature or module addition (bumps **minor** version)
- [ ] `fix:` — Bug fix or correction (bumps **patch** version)
- [ ] `chore:` — Maintenance, dependency update, or documentation (bumps **patch** version)
- [ ] `feat!:` or `BREAKING CHANGE` — Breaking change (bumps **major** version)

## Description

Describe what this PR changes and why.

## Changes Made

- 
- 
- 

## Module Impact

Which modules are affected by this change?

- [ ] `modules/landing-zone`
- [ ] `modules/application`
- [ ] GitHub Actions workflows
- [ ] Documentation only

## Testing

- [ ] `terraform validate` passes locally
- [ ] `terraform plan` output reviewed — changes are expected and correct
- [ ] Checkov scan passes, or any findings are documented below with justification
- [ ] Changes tested against a non-production environment

## Checkov Findings

List any Checkov findings from this PR and their status:

| Check ID | Description | Status | Justification |
|----------|-------------|--------|---------------|
| | | Passed / Skipped | |

## Consumer Impact

- [ ] This change requires consumer repos to update their module source `ref` tag
- [ ] Variable additions are backwards compatible (have defaults)
- [ ] Breaking variable changes are documented in the description above

## Checklist

- [ ] Commit message follows [Conventional Commits](https://www.conventionalcommits.org/) format
- [ ] No sensitive values committed (passwords, keys, connection strings)
- [ ] README updated if inputs, outputs, or behaviour changed
