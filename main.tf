provider "azurerm" {
  version = "~>2.0"
  features {}
}

provider "hcs" { }

resource "azurerm_resource_group" "rg" {
  name     = "federation-test-hans-1"
  location = "westus2"
}

output "rg" {
  value = azurerm_resource_group.rg.name
}
output "url" {
  value = hcs_cluster.dc1.consul_external_endpoint_url
}
output "token" {
  value = hcs_cluster.dc1.consul_root_token_secret_id
}

// Create dc1
resource "hcs_cluster" "dc1" {
  resource_group_name      = azurerm_resource_group.rg.name
  managed_application_name = "dc1"
  email                    = "hans@hashicorp.com"
  cluster_mode             = "production"
  min_consul_version       = "v1.9.1"
  vnet_cidr                = "172.25.16.0/24"
  consul_datacenter        = "dc1"
  consul_external_endpoint = true
}

// Create a federation token
data "hcs_federation_token" "dc1" {
  resource_group_name      = hcs_cluster.dc1.resource_group_name
  managed_application_name = hcs_cluster.dc1.managed_application_name
}

// Create dc2
resource "hcs_cluster" "dc2" {
  resource_group_name      = azurerm_resource_group.rg.name
  managed_application_name = "dc2"
  email                    = "hans@hashicorp.com"
  cluster_mode             = "production"
  min_consul_version       = "v1.9.1"
  vnet_cidr                = "172.25.17.0/24"
  consul_datacenter        = "dc2"
  consul_federation_token  = data.hcs_federation_token.dc1.token
  consul_external_endpoint = true
}

// Create dc3
resource "hcs_cluster" "dc3" {
  resource_group_name      = azurerm_resource_group.rg.name
  managed_application_name = "dc3"
  email                    = "hans@hashicorp.com"
  cluster_mode             = "production"
  min_consul_version       = "v1.9.1"
  vnet_cidr                = "172.25.18.0/24"
  consul_datacenter        = "dc3"
  consul_federation_token  = data.hcs_federation_token.dc1.token
  consul_external_endpoint = true
}

# Network setup
# vnet1, vnet2, vnet3 with subnets, peered together
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

resource "azurerm_virtual_network" "vnet3" {
  name                = "vnet3"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["12.0.0.0/8"]
}
resource "azurerm_subnet" "subnet3" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet3.name
  address_prefixes     = ["12.0.0.0/16"]
}

# peer AKS vnets
resource "azurerm_virtual_network_peering" "aks1_to_aks2" {
  name                      = "aks1_to_aks2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "aks2_to_aks1" {
  name                      = "aks2_to_aks1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "aks1_to_aks3" {
  name                      = "aks1_to_aks3"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "aks3_to_aks1" {
  name                      = "aks3_to_aks1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet3.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "aks2_to_aks3" {
  name                      = "aks2_to_aks3"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "aks3_to_aks2" {
  name                      = "aks3_to_aks2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet3.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# peer to HCS
data "azurerm_virtual_network" "hcsvnet1" {
  name                = hcs_cluster.dc1.vnet_name
  resource_group_name = hcs_cluster.dc1.managed_resource_group_name
}
resource "azurerm_virtual_network_peering" "aks1_to_hcs1" {
  name                      = "aks1_to_hcs1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "hcs1_to_aks1" {
  name                      = "hcs1_to_aks1"
  resource_group_name       = hcs_cluster.dc1.managed_resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hcsvnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
data "azurerm_virtual_network" "hcsvnet2" {
  name                = hcs_cluster.dc2.vnet_name
  resource_group_name = hcs_cluster.dc2.managed_resource_group_name
}
resource "azurerm_virtual_network_peering" "aks2_to_hcs2" {
  name                      = "aks2_to_hcs2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "hcs2_to_aks2" {
  name                      = "hcs2_to_aks2"
  resource_group_name       = hcs_cluster.dc2.managed_resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hcsvnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
data "azurerm_virtual_network" "hcsvnet3" {
  name                = hcs_cluster.dc3.vnet_name
  resource_group_name = hcs_cluster.dc3.managed_resource_group_name
}
resource "azurerm_virtual_network_peering" "aks3_to_hcs3" {
  name                      = "aks3_to_hcs3"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet3.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "hcs3_to_aks3" {
  name                      = "hcs3_to_aks3"
  resource_group_name       = hcs_cluster.dc3.managed_resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hcsvnet3.name
  remote_virtual_network_id = azurerm_virtual_network.vnet3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# AKS cluster setup
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

resource "azurerm_kubernetes_cluster" "dc3" {
  identity {
    type = "SystemAssigned"
  }
  name                = "dc3"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "dc3-dns"

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
    vnet_subnet_id = azurerm_subnet.subnet3.id
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "12.233.0.10"
    service_cidr = "12.233.0.0/16"
    docker_bridge_cidr = "172.171.0.1/16"
  }
}
