# Entra-Zero-Trust-Lab

Entra Zero Trust Lab — EG Identity Labs
A hands-on zero-trust identity lab in Microsoft Entra ID + Azure, built with Terraform and deployed through GitHub Actions with OpenID Connect (OIDC).
>
No stored Azure credentials in CI — GitHub authenticates to Azure with short-lived federated tokens.
Status: Lab Complete
CI: Plan | Apply
Stack: Entra ID, Azure, Terraform, GitHub Actions

What is this?
Proves a small, realistic identity boundary end to end
Users get access through groups, never through individual assignments
Conditional Access enforces MFA and blocks legacy authentication
Privileged access is eligible-only and time-bound, not standing
Secrets live in Key Vault with role-based access
Boundaries are tested with real logins, not just portal screenshots
Infrastructure is code, and changes go through a PR plan → merge apply pipeline in CI

Architecture
flowchart LR
    GH[GitHub Actions] -->|OIDC federated token| ENTRA[Entra ID]
    ENTRA -->|Contributor on rg-identity-lab only| AZ[Azure]
    AZ --> KV[Key Vault]
    AZ --> VNET[VNet + NSG]
    AZ --> LAW[Log Analytics]
    USER[Users in groups] --> CA[Conditional Access]
    CA --> KV
    PIM[PIM eligible access] --> AZ

What was built
Identity & access
Control
What it does
Status
CA01
Requires MFA for all users (break-glass excluded)
On, proven with a real sign-in
CA02
Blocks legacy authentication
On, proven with What-if
CA03
Contractor restrictions — MFA + reauthentication every 4 hours
On, proven with a contractor test user
Security Defaults
Disabled, so Conditional Access is the enforcement point
Disabled before CA01 went On
PIM
Eligible Contributor on rg-identity-lab, max 1 hour, MFA + justification required
Complete, live activation tested
Break-glass
Emergency Global Admin, excluded from every CA policy
Created and login-tested
Groups used throughout: IT-Admins, Finance-Users, HR-Users, Contractors, PIM-Azure-Contributors
Access rule: granted to groups, never to individual users
Terraform resources — 9 in one apply
Resource group reference (built on Day 1, managed, not recreated)
Virtual network 10.10.0.0/16, subnet 10.10.1.0/24
NSG with zero custom inbound rules on purpose, plus the subnet association
Log Analytics workspace (PerGB2018, 30-day retention)
Key Vault with RBAC authorization, purge protection on, soft-delete 7 days
Diagnostic setting sending Key Vault audit events to Log Analytics
Role assignments:
IT-Admins → Key Vault Secrets Officer
Finance-Users → Key Vault Secrets User

Proof it works
Key Vault access boundaries — tested with live logins
User
Role
Create a secret
List / read a secret
Result
Diego (IT-Admins)
Secrets Officer
Allowed
Allowed
As designed
Frank (Finance-Users)
Secrets User
Forbidden (setSecret denied)
Allowed for his own secret
As designed
HR user (no Key Vault role)
None
—
Forbidden (readMetadata denied)
As designed
Finding worth knowing:
Finance users can't even see the vault in the Azure portal
Reason: a data-plane role gives no management-plane Reader access
Their access was proven through the CLI, not the portal
Portal visibility is not proof of access, and lack of portal visibility is not proof of no access
CI/CD — proven green
Check
Trigger
Result
PR plan
Pull request touching terraform/
Green, no changes on a comment-only test change
Merge apply
Merge to main
Green, no changes
<!-- Add screenshots here: green PR plan run, green merge apply run, federated-credentials blade -->

How to reproduce it (short version)
This README is the overview. The full step-by-step tutorial lives separately — see Tutorial below.
Prerequisites:
An Entra ID tenant with P2
An Azure subscription
Terraform
Azure CLI
A GitHub repo
Steps:
Create the Entra groups and test users, plus a break-glass Global Admin excluded from all CA policies
Build CA01, CA02, and CA03 in Report-only, test them, disable Security Defaults, then switch them On
Set up PIM: eligible Contributor on the lab resource group, capped at 1 hour, requiring MFA + justification
Write the Terraform configuration and apply it locally
Verify the Key Vault boundaries with the three logins above
Migrate state to an Azure Storage backend (resource group, storage account, tfstate container)
Create the Entra app registration for GitHub Actions, its service principal, and two federated credentials:
One for main (apply)
One for pull requests (plan)
Give the service principal Contributor on the lab resource group only
Save the GitHub repo Variables:
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
TF_VAR_it_admins_group_id
TF_VAR_finance_users_group_id
Add .github/workflows/terraform.yml:
Plan on PRs touching terraform/
Apply on pushes to main
Commit and push
Prove it:
Open a PR touching terraform/ for a green plan
Merge it for a green apply

Tutorial
The detailed, step-by-step guide is kept separate from this README so the two don't drift apart
[Full tutorial — link to your guide / docs folder here]

Lessons learned
1. Federated-credential subjects are case-sensitive
GitHub sends the repo name exactly as it is on GitHub
In this repo, that's Entra-Zero-Trust-Lab with capitals
A credential created with lowercase entra-zero-trust-lab fails login with AADSTS700213
The names look identical at a glance — Azure still rejects them
Fix the credential to match GitHub's exact casing
Don't rename the repo to fit the typo
2. GitHub Variable names must match exactly, or Terraform gets null
A variable saved as IT_Finance_user is invisible to a workflow asking for TF_VAR_finance_users_group_id
Result: a plan trying to replace the Finance-Users Key Vault assignment
Reason: its principal came through as null
Then apply hit a 403 trying to delete it, because Contributor deliberately excludes managing role assignments
Fix the variable name, not the permission
3. Verify role assignments from the resource scope, not with an assignee filter
An assignee-filtered list can return empty even when the assignment exists
The scoped list is the reliable check
4. A silent command is not a failed command
mkdir -p and variable assignments print nothing on success
Verify with a listing
Don't re-run blindly

Cost & cleanup
Lab resources are small:
One resource group
One VNet
One Key Vault
One Log Analytics workspace
Set a budget alert before building
This lab used a $5 alert
To tear down:
terraform destroy from the terraform/ directory
Remove the Entra app registration and federated credentials
Delete the storage account holding state if you no longer need it
No secrets, passwords, or credentials are stored in this repo
State files and .tfvars are excluded from version control

Repository structure
.github/workflows/terraform.yml   # OIDC plan (PR) and apply (main) pipeline
terraform/
  main.tf                         # VNet, NSG, Log Analytics, Key Vault, role assignments
  providers.tf                    # azurerm provider pin
  backend.tf                      # Azure Storage remote backend
  variables.tf                    # Group IDs as variables (values are local / CI-only)

Next steps
README / diagram polish (this document)
Expand the Key Vault tests with a second secret and a second Finance user
Add Authentik SSO in front of a ticketing-system lab as a separate project
Investigate Conditional Access authentication strengths (passkeys) as a follow-on control

Built as a portfolio lab. Not affiliated with Microsoft. Test users and groups are lab-only and contain no production data.
