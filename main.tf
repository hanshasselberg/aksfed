provider "azurerm" {
  version = "~>2.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = "aks-test-hans"
  location = "westus2"
}

# Network setup
# vnet1 and vnet2 with subnets, peered together
resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/8"]
}
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "vnet2" {
  name                = "vnet2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["11.0.0.0/8"]
}
resource "azurerm_subnet" "subnet2" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["11.0.0.0/16"]
}

resource "azurerm_virtual_network_peering" "peer1to2" {
  name                      = "peer1to2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
}
resource "azurerm_virtual_network_peering" "peer2to1" {
  name                      = "peer2to1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
}

resource "azurerm_kubernetes_cluster" "dc1" {
  identity {
    type = "SystemAssigned"
  }
  name                = "dc1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
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
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
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
