provider "azurerm" {
  version = "~> 1.33.0"
}

resource "azurerm_resource_group" "resource_group" {
  name = "AllTheClouds"
  location = "Central US"
}

resource "azurerm_storage_account" "storage_account" {
  name = "alltheclouds"
  location = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "service_plan" {
  name = "AllTheClouds"
  location = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  kind = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_storage_container" "storage_container" {
  name = "alltheclouds"
  storage_account_name = azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

data "archive_file" "azure_function_source" {
  type = "zip"
  source_dir = "../backend/azure"
  output_path = "${path.module}/azure-function.zip"
}

resource "azurerm_storage_blob" "function_blob" {
  name = "function.zip"

  resource_group_name = azurerm_resource_group.resource_group.name
  storage_account_name = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.storage_container.name

  type = "block"
  source = data.archive_file.azure_function_source.output_path
}

data "azurerm_storage_account_sas" "shared_access_signature" {
  connection_string = azurerm_storage_account.storage_account.primary_connection_string
  https_only        = false
  resource_types {
    service   = false
    container = false
    object    = true
  }
  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  start  = "2019-08-24"
  expiry = "2029-08-24"
  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
  }
}

resource "azurerm_function_app" "function" {
  name = "AllTheClouds-Backend"
  version = "~2"
  location = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  app_service_plan_id = azurerm_app_service_plan.service_plan.id
  storage_connection_string = azurerm_storage_account.storage_account.primary_connection_string

  app_settings = {
    HASH = filebase64sha256(data.archive_file.azure_function_source.output_path)
    WEBSITE_USE_ZIP = "https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}/${azurerm_storage_blob.function_blob.name}${data.azurerm_storage_account_sas.shared_access_signature.sas}"
    WEBSITE_NODE_DEFAULT_VERSION = "10.15.2"
  }
  auth_settings {
    enabled = false
  }
  site_config {
    cors {
      allowed_origins = ["*"]
    }
  }
}

resource "azurerm_app_service_custom_hostname_binding" "custom_hostname" {
  hostname            = "api.alltheclouds.app"
  app_service_name    = azurerm_function_app.function.name
  resource_group_name = azurerm_resource_group.resource_group.name
}