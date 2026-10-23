# Reference the resource group built on Day 1 — Terraform manages what's
# inside it; it does not recreate the group itself.

data "azurerm_resource_group" "lab" {
  name = "rg-identity-lab"
}

data "azurerm_client_config" "current" {}

locals {
  location = data.azurerm_resource_group.lab.location
  tags = {
    project     = "zero-trust-identity-lab"
    environment = "lab"
    managed_by  = "terraform"
  }
}

variable "it_admins_group_id" {
  description = "Object ID of the IT-Admins Entra group"
  type        = string
}

variable "finance_users_group_id" {
  description = "Object ID of the Finaance-Users Entra group"
  type        = string
}

variable "key_vault_name" {
  description = "Gloabally unique Key Vault name"
  type        = string
  default     = "kv-egidentitylab-1023"
}

# ---------------- Network ----------------

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-identity-lab"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.tags
}


resource "azurerm_subnet" "workloads" {
  name                 = "snet-workloads"
  resource_group_name  = data.azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "workloads" {
  name                = "nsg-workloads"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  tags                = local.tags

  # No custom inbound rules on purpose: Azure's defaults deny unsolicited
  # inbound internet traffic. Deliberately NOT adding Allow-RDP/SSH.
}

resource "azurerm_subnet_network_security_group_association" "workloads" {
  subnet_id                 = azurerm_subnet.workloads.id
  network_security_group_id = azurerm_network_security_group.workloads.id
}

# ---------------- Logging ----------------
resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-identity-lab"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# ---------------- Key Vault ----------------
resource "azurerm_key_vault" "lab" {
  name                       = var.key_vault_name
  location                   = local.location
  resource_group_name        = data.azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
  tags                       = local.tags
}
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "kv-to-log-analytics"
  target_resource_id         = azurerm_key_vault.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "AuditEvent"
  }
}

# --------- Key Vault data-plane RBAC (groups, never individuals) ---------
resource "azurerm_role_assignment" "kv_admins_officer" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.it_admins_group_id
}

resource "azurerm_role_assignment" "kv_finance_user" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.finance_users_group_id
}

output "key_vault_uri" {
  value = azurerm_key_vault.lab.vault_uri
}

