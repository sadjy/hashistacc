variable "namespace" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "max_instance_count" {
  type = number
  default = 0
}

variable "instance_type" {
  type = string
  default = "t4g.nano"
}

variable "vpc" {
  type = any
}

variable "security_group_id" {
  type = string
}

variable "ssh_keypair" {
  type = string
}

variable "target_group_arns" {
  type    = list(string)
  default = []
}

variable "datacenter" {
  type = string
}

variable "join_wan" {
  default = []
  type    = list(string)
}

variable "associate_public_ips" {
  default = true
  type    = bool
}

variable "nomad" {
  default = {
    version = "n/a"
    mode    = "disabled"
  }
  type = object({
    version = string
    mode    = string
  })
}

variable "consul" {
  default = {
    version = "n/a"
    mode    = "disabled"
  }
  type = object({
    version = string
    mode    = string
  })
}

variable "vault" {
  default = {
    version = "n/a"
    mode    = "disabled"
  }
  type = object({
    version = string
    mode    = string
  })
}

variable "encrypt_id" {}

variable "vault_lb" {}

variable "approles" {}

variable "join_vault" {
  default = ""
  type = string
}