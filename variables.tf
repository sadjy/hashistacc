variable domain {
  default = "sadj.io"
}

variable "vault" {
  default = {
    version = "",
    servers_count = 1,
    server_instance_type = "t4g.nano"
  }
}

variable "ssh_keypair" {
  default = "TMP-proj"
  type    = string
}

