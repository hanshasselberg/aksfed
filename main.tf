variable rg {}

locals {
  dc1data = jsondecode(file("${path.module}/${var.rg}-hcs-dc1.json"))
  dc2data = jsondecode(file("${path.module}/${var.rg}-hcs-dc2.json"))
}

provider "azurerm" {
  version = "~>2.0"
  features {}
}

# Network setup
# vnet1 and vnet2 with subnets, peered together
resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  location            = "westus2"
  resource_group_name = var.rg
  address_space       = ["10.0.0.0/8"]
}
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "vnet2" {
  name                = "vnet2"
  location            = "westus2"
  resource_group_name = var.rg
  address_space       = ["11.0.0.0/8"]
}
resource "azurerm_subnet" "subnet2" {
  name                 = "subnet"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["11.0.0.0/16"]
}

# peer AKS vnets
resource "azurerm_virtual_network_peering" "peer1to2" {
  name                      = "peer1to2"
  resource_group_name       = var.rg
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "peer2to1" {
  name                      = "peer2to1"
  resource_group_name       = var.rg
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# peer to HCS
data "azurerm_virtual_network" "hcsvnet1" {
  name                = "${local.dc1data.outputs.vnet_name.value}-vnet"
  resource_group_name = "${var.rg}-mrg-dc1"
}
resource "azurerm_virtual_network_peering" "peerhcs1to1" {
  name                      = "peerhcs1to1"
  resource_group_name       = var.rg
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "peerhcs1to2" {
  name                      = "peerhcs1to2"
  resource_group_name       = "${var.rg}-mrg-dc1"
  virtual_network_name      = data.azurerm_virtual_network.hcsvnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
data "azurerm_virtual_network" "hcsvnet2" {
  name                = "${local.dc2data.outputs.vnet_name.value}-vnet"
  resource_group_name = "${var.rg}-mrg-dc2"
}
resource "azurerm_virtual_network_peering" "peerhcs2to1" {
  name                      = "peerhcs2to1"
  resource_group_name       = var.rg
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "peerhcs2to2" {
  name                      = "peerhcs2to2"
  resource_group_name       = "${var.rg}-mrg-dc2"
  virtual_network_name      = data.azurerm_virtual_network.hcsvnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# AKS cluster setup
resource "azurerm_kubernetes_cluster" "dc1" {
  identity {
    type = "SystemAssigned"
  }
  name                = "dc1"
  location            = "westus2"
  resource_group_name = var.rg
  dns_prefix          = "dc1-dns"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  default_node_pool {
    name            = "agentpool"
    node_count      = 3
    vm_size         = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.subnet1.id
  }

  network_profile {
    network_plugin = "kubenet"
    dns_service_ip = "10.233.0.10"
    service_cidr = "10.233.0.0/16"
    pod_cidr = "10.244.0.0/16"
    docker_bridge_cidr = "172.171.0.1/16"
  }
}

resource "azurerm_kubernetes_cluster" "dc2" {
  identity {
    type = "SystemAssigned"
  }
  name                = "dc2"
  location            = "westus2"
  resource_group_name = var.rg
  dns_prefix          = "dc2-dns"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  default_node_pool {
    name            = "agentpool"
    node_count      = 3
    vm_size         = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.subnet2.id
  }

  network_profile {
    network_plugin = "kubenet"
    dns_service_ip = "11.233.0.10"
    service_cidr = "11.233.0.0/16"
    pod_cidr = "11.244.0.0/16"
    docker_bridge_cidr = "172.171.0.1/16"
  }
}
