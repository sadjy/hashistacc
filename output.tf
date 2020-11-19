
output "public_ips" {
    value = {
        consul_servers_1 = module.eu-west-3.public_ips.consul_servers
        nomad_servers_1 = module.eu-west-3.public_ips.nomad_servers
        vault_servers_1 = module.eu-west-3.public_ips.vault_servers
/*        consul_servers_2 = module.us-east-2.public_ips.consul_servers
        nomad_servers_2 = module.us-east-2.public_ips.nomad_servers
        vault_servers_2 = module.us-east-2.public_ips.vault_servers */
    }
}

output "lb_addresses_eu-west-3" {
    value = module.eu-west-3.addresses
}

/*output "lb_addresses_us-east-2" {
    value = module.us-east-2.addresses
}*/

/*
output "dns_names" {
    value = module.eu-west-3.dns_names
}
*/


/*
output "lb_endpoints" {
    value = [
        module.eu-west-3.endpoints,
        module.us-east-2.endpoints
    ]
}*/

output "uuids" {
    value = [
        random_uuid.role_id_consul.result,
        random_uuid.role_id_nomad_server.result,
        random_uuid.role_id_nomad_cluster.result
    ]
}

