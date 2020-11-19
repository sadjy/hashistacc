provider "aws" {
  region = var.region
}

module "resourcegroup" {
  source = "./modules/resourcegroup"
  namespace = var.namespace
}

module "networking" {
  source    = "./modules/networking"
  namespace = module.resourcegroup.namespace
}

module "loadbalancing" {
  source = "./modules/loadbalancing"

  namespace = module.resourcegroup.namespace
  sg        = module.networking.sg
  vpc       = module.networking.vpc
}

module "consul_servers" {
  source               = "./modules/cluster"
  associate_public_ips = var.associate_public_ips
  ssh_keypair          = var.ssh_keypair
  instance_count       = var.consul.servers_count
  instance_type        = var.consul.server_instance_type
  datacenter           = var.datacenter
  join_wan             = var.join_wan
  consul = {
    version = var.consul.version
    mode    = "server"
  }
  vault = {
    version = var.vault.version
    mode    = "agent"
  }
  namespace         = module.resourcegroup.namespace
  vpc               = module.networking.vpc
  security_group_id = module.networking.sg.consul_server
  target_group_arns = module.loadbalancing.target_group_arns.consul
  approles          = var.approles
  encrypt_id        = var.encrypt_id
  vault_lb          = var.join_vault != "" ? var.join_vault : module.loadbalancing.addresses.vault_lb 
}

module "nomad_servers" {
  source               = "./modules/cluster"
  associate_public_ips = var.associate_public_ips
  ssh_keypair          = var.ssh_keypair
  instance_count       = var.nomad.servers_count
  instance_type        = var.nomad.server_instance_type
  datacenter           = var.datacenter
  nomad = {
    version = var.nomad.version
    mode    = "server"
  }
  consul = {
    version = var.consul.version
    mode    = "client"
  }
  vault = {
    version = var.vault.version
    mode    = "agent"
  }
  namespace         = module.resourcegroup.namespace
  vpc               = module.networking.vpc
  security_group_id = module.networking.sg.nomad_server
  target_group_arns = module.loadbalancing.target_group_arns.nomad
  approles          = var.approles
  encrypt_id        = var.encrypt_id
  vault_lb          = var.join_vault != "" ? var.join_vault : module.loadbalancing.addresses.vault_lb 
}

module "nomad_clients" {
  source               = "./modules/cluster"
  associate_public_ips = var.associate_public_ips
  ssh_keypair          = var.ssh_keypair
  instance_count       = var.nomad.clients_count
  max_instance_count   = var.nomad.max_clients_count
  instance_type        = var.nomad.client_instance_type
  datacenter           = var.datacenter
  nomad = {
    version = var.nomad.version
    mode    = "client"
  }
  consul = {
    version = var.consul.version
    mode    = "client"
  }
  vault = {
    version = var.vault.version
    mode    = "agent"
  }
  namespace         = module.resourcegroup.namespace
  security_group_id = module.networking.sg.nomad_client
  vpc               = module.networking.vpc
  target_group_arns = module.loadbalancing.target_group_arns.fabio
  approles          = var.approles
  encrypt_id        = var.encrypt_id
  vault_lb          = var.join_vault != "" ? var.join_vault : module.loadbalancing.addresses.vault_lb 
}

module "vault_servers" {
  source               = "./modules/cluster"
  associate_public_ips = var.associate_public_ips
  ssh_keypair          = var.ssh_keypair
  instance_count       = var.vault.servers_count
  instance_type        = var.vault.server_instance_type
  datacenter           = var.datacenter
  vault = {
    version = var.vault.version
    mode    = "server"
  }
  consul = {
    version = var.consul.version
    mode    = "client"
  }
  namespace         = module.resourcegroup.namespace
  vpc               = module.networking.vpc
  security_group_id = module.networking.sg.vault_server
  target_group_arns = module.loadbalancing.target_group_arns.vault
  approles          = var.approles
  encrypt_id        = var.encrypt_id
  vault_lb          = var.join_vault != "" ? var.join_vault : module.loadbalancing.addresses.vault_lb 
}

# Cloudflare provider 
/*
data "cloudflare_zones" "domain" {
  filter {
    name   = var.domain
    status = "active"
    paused = false
  }
}

resource "cloudflare_record" "cname" {
  for_each = module.loadbalancing.dns_names
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = "${each.key}.${var.datacenter}"
  value   = each.value
  type    = "CNAME"
  ttl     = 3600
}*/
