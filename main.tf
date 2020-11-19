resource "random_uuid" "role_id_nomad_server" {}
resource "random_uuid" "secret_id_nomad_server" {}
resource "random_uuid" "role_id_nomad_cluster" {}
resource "random_uuid" "secret_id_nomad_cluster" {}
resource "random_uuid" "role_id_consul" {}
resource "random_uuid" "secret_id_consul" {}
resource "random_id" "encrypt_id" {
    byte_length = 16
}

module "eu-west-3" {
  source  = "./aws-cluster"
  region = "eu-west-3"
  ssh_keypair = var.ssh_keypair
  vault = var.vault
  datacenter = "dc1"
  domain = var.domain
  approles = {
    "consul" = {
      "role_id" = random_uuid.role_id_consul.result,
      "secret_id" = random_uuid.role_id_consul.result
      }, 
    "nomad_server" = {
      "role_id" = random_uuid.role_id_nomad_server.result,
      "secret_id" = random_uuid.secret_id_nomad_server.result
      },
    "nomad_cluster" = {
      "role_id" = random_uuid.role_id_nomad_cluster.result,
      "secret_id" = random_uuid.secret_id_nomad_cluster.result
      }
    }
  encrypt_id = random_id.encrypt_id.b64_std
}

# module "us-east-2" {
#   source  = "./nomad-consul-cluster"
#   region = "us-east-2"
#   ssh_keypair = var.ssh_keypair
#   datacenter = "dc2"
#   domain = var.domain
#   approles = {
#     "consul" = {
#       "role_id" = random_uuid.role_id_consul.result,
#       "secret_id" = random_uuid.role_id_consul.result
#       }, 
#     "nomad_server" = {
#       "role_id" = random_uuid.role_id_nomad_server.result,
#       "secret_id" = random_uuid.secret_id_nomad_server.result
#       },
#     "nomad_cluster" = {
#       "role_id" = random_uuid.role_id_nomad_cluster.result,
#       "secret_id" = random_uuid.secret_id_nomad_cluster.result
#       }
#     }
#   join_wan = module.eu-west-3.public_ips.consul_servers
#   encrypt_id = random_id.encrypt_id.b64_std
#   join_vault = module.eu-west-3.addresses.vault_lb
# }

