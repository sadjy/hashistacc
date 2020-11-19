output "addresses" {
    value = module.loadbalancing.addresses
}

output "public_ips" {
    value = {
        consul_servers = module.consul_servers.public_ips
        nomad_servers = module.nomad_servers.public_ips
        vault_servers = module.vault_servers.public_ips
    }
}

output "dns_names" {
    value = module.loadbalancing.dns_names
}

/*
output "endpoints" {
  value = cloudflare_record.cname[*]
}
*/
