resource "null_resource" "hcs" {
  provisioner "local-exec" {
    command = "./before.sh"
  }
}

provider "azurerm" {
  version = "~>2.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = "aks-test-hans"
  location = "westus2"

  depends_on [
    null_resource.hcs,
  ]
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

# peer AKS vnets
resource "azurerm_virtual_network_peering" "peer1to2" {
  name                      = "peer1to2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "peer2to1" {
  name                      = "peer2to1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

locals {
  dc1data = jsondecode(file("${path.module}/dc1.json"))
  dc2data = jsondecode(file("${path.module}/dc2.json"))
}

# peer to HCS
data "azurerm_virtual_network" "hcsvnet1" {
  name                = "${local.dc1data.outputs.vnet_name.value}-vnet"
  resource_group_name = "hcs-definition-hans-mrg-dc1"
}
resource "azurerm_virtual_network_peering" "peerhcs1to1" {
  name                      = "peerhcs1to1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "peerhcs1to2" {
  name                      = "peerhcs1to2"
  resource_group_name       = "hcs-definition-hans-mrg-dc1"
  virtual_network_name      = data.azurerm_virtual_network.hcsvnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
data "azurerm_virtual_network" "hcsvnet2" {
  name                = "${local.dc2data.outputs.vnet_name.value}-vnet"
  resource_group_name = "hcs-definition-hans-mrg-dc2"
}
resource "azurerm_virtual_network_peering" "peerhcs2to1" {
  name                      = "peerhcs2to1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcsvnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_virtual_network_peering" "peerhcs2to2" {
  name                      = "peerhcs2to2"
  resource_group_name       = "hcs-definition-hans-mrg-dc2"
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

# provider "helm" {
#   alias = "dc1"
#   kubernetes {
#     host = azurerm_kubernetes_cluster.dc1.kube_config[0].host

#     client_key             = base64decode(azurerm_kubernetes_cluster.dc1.kube_config[0].client_key)
#     client_certificate     = base64decode(azurerm_kubernetes_cluster.dc1.kube_config[0].client_certificate)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.dc1.kube_config[0].cluster_ca_certificate)
#     load_config_file       = false
#   }
# }

# provider "helm" {
#   alias = "dc2"
#   kubernetes {
#     host = azurerm_kubernetes_cluster.dc2.kube_config[0].host

#     client_key             = base64decode(azurerm_kubernetes_cluster.dc2.kube_config[0].client_key)
#     client_certificate     = base64decode(azurerm_kubernetes_cluster.dc2.kube_config[0].client_certificate)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.dc2.kube_config[0].cluster_ca_certificate)
#     load_config_file       = false
#   }
# }

# resource "helm_release" "primary" {
#   provider = helm.dc1
#   name  = "primary"
#   chart = "hashicorp/consul"
#   repository = "https://helm.releases.hashicorp.com"

#   values = [
#     "${file("dc1.yaml")}"
#   ]

#   set {
#     name = "meshGateway.enabled"
#     value = "true"
#   }

#   depends_on = [
#     helm_release.aws_vpc_cni
#   ]
# }
