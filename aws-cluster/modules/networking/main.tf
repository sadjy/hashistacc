data "aws_availability_zones" "available" {}

module "vpc" {
  source                           = "terraform-aws-modules/vpc/aws"
  version                          = "2.64.0"
  name                             = "${var.namespace}-vpc"
  cidr                             = "10.0.0.0/16"
  azs                              = data.aws_availability_zones.available.names
  private_subnets                  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets                   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway               = true
  single_nat_gateway               = true
  tags = {
    ResourceGroup = var.namespace
  }
}

module "consul_server_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Consul server SG"
  ingress_rules = [
    {
      port        = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8300
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8301
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8302
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8500
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "consul_lb_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Consul LB SG"
  ingress_rules = [
    {
      port        = 8500
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "nomad_server_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Nomad server SG"
  ingress_rules = [
    {
      port        = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 4646
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 4647
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 4648
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8300
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8301
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "nomad_lb_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Nomad LB SG"
  ingress_rules = [
    {
      port        = 4646
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "nomad_client_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Nomad client SG"
  ingress_rules = [
    {
      port        = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 4646
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 4647
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 4648
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8300
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8301
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 9998
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 9999
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 30303
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8546
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 6688
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "fabio_lb_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Fabio LB SG"
  ingress_rules = [
    {
      port        = 9998
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 9999
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "vault_server_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Vault server SG"
  ingress_rules = [
    {
      port        = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8300
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8301
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8200
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 8201
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "vault_lb_sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
  name = "Vault LB SG"
  ingress_rules = [
    {
      port        = 8200
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}