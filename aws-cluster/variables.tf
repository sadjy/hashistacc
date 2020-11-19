variable "region" {}

variable "domain" {
  type = string
}

variable "consul" {
  default = {
    version              = "1.8.5"
    servers_count        = 2
    server_instance_type = "t4g.nano"
  }
  type = object({
    version              = string
    servers_count        = number
    server_instance_type = string
  })
}

variable "nomad" {
  default = {
    version              = "0.12.7"
    servers_count        = 2
    server_instance_type = "t4g.nano"
    clients_count        = 2
    max_clients_count    = 10
    client_instance_type = "t4g.nano"
  }
  type = object({
    version              = string
    servers_count        = number
    server_instance_type = string
    clients_count        = number
    max_clients_count    = number
    client_instance_type = string
  })
}

variable "vault" {
  default = {
    version              = "1.6.0-rc"
    servers_count        = 0
    server_instance_type = "t4g.nano"
  }
  type = object({
    version              = string
    servers_count        = number
    server_instance_type = string
  })
}

variable "namespace" {
  default = "terraform"
  type    = string
}

variable "ssh_keypair" {
  default = null
  type    = string
}

variable "datacenter" {
  default = "aws"
  type    = string
}

variable "join_wan" {
  type    = list(string)
  default = []
}

variable "associate_public_ips" {
  default = true
  type = bool
}

variable "encrypt_id" {
  type = string
}

variable "approles" {
  type = map(object({
    role_id = string
    secret_id = string
  }))
}

variable "join_vault" {
  type    = string
  default = ""
}