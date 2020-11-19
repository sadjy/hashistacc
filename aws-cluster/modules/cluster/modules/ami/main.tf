locals {
  packer_config = templatefile("${path.module}/../../../../../templates/packer/config.json", {
    consul_version = var.consul_version,
    nomad_version  = var.nomad_version,
    vault_version  = var.vault_version,
    region         = var.region,
    script_dir     = "${path.cwd}/templates/packer"
  }) 
  build = templatefile("${path.module}/build.sh", {
    packer_config  = local.packer_config,
    region         = var.region,
    script_dir     = "${path.cwd}/templates/packer"
  })
}

# resource "null_resource" "ami" {
#   provisioner "local-exec" {
#     command = "packer build ${locals.packer_config} grep ami- | cut -d ' ' -f 2"
#   }
# }

data "external" "ami" {
  program = ["/bin/bash", "-c", local.build]
}