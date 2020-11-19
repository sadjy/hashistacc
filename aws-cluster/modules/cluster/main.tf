
module "iam_instance_profile" {
  source  = "./modules/iip"
  actions = ["logs:*", "ec2:DescribeInstances", "cloudwatch:PutMetricData"]
}

module "iam_instance_profile_vault_server" {
  source  = "./modules/iip"
  actions = ["logs:*", "ec2:DescribeInstances", "kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
}

resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 10
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ami" "ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["hashistacc-ubuntu20-*"]
  }
  owners = [data.aws_caller_identity.current.account_id]
}

# module "ami" {
#   source = "./modules/ami"
#   consul_version = var.consul.version
#   nomad_version  = var.nomad.version
#   vault_version  = var.vault.version
#   region         = data.aws_region.current.name
#   count          = data.aws_ami.ami.id != "" ? 0 : 1
# }

locals {
  consul_config = var.consul.mode != "disabled" ? templatefile("${path.module}/../../../templates/consul/consul_${var.consul.mode}.json", {
    instance_count = var.instance_count,
    namespace      = var.namespace,
    datacenter     = var.datacenter,
    join_wan       = join(",",[for s in var.join_wan: join("",["\"",s,"\""])]),
    encrypt_id     = var.encrypt_id
  }) : ""
  nomad_config = var.nomad.mode != "disabled" ? templatefile("${path.module}/../../../templates/nomad/nomad_${var.nomad.mode}.hcl", {
    instance_count = var.instance_count,
    datacenter     = var.datacenter,
    region         = "global",
    encrypt_id     = var.encrypt_id
  }) : ""
  vault_config = var.vault.mode != "disabled" ? templatefile("${path.module}/../../../templates/vault/vault_${var.vault.mode}.hcl", {
    instance_count = var.instance_count,
    datacenter     = var.datacenter,
    kms_key        = aws_kms_key.vault.id,
    region         = data.aws_region.current.name,
    vault_lb       = var.join_vault != "" ? var.join_vault : var.vault_lb,
    nomad_mode     = var.nomad.mode,
    consul_mode     = var.consul.mode
  }) : ""  
  startup = templatefile("${path.module}/../../../templates/startup.sh", {
    consul_config  = local.consul_config,
    consul_mode    = var.consul.mode,
    nomad_config   = local.nomad_config,
    nomad_mode     = var.nomad.mode,
    vault_config   = local.vault_config,
    vault_mode     = var.vault.mode,    
    region         = data.aws_region.current.name,
    approles       = var.approles
  })
  namespace = "${var.namespace}_V${var.vault.mode}_N${var.nomad.mode}_C${var.consul.mode}"
}

resource "aws_launch_template" "server" {
  name_prefix   = local.namespace
#  image_id      = data.aws_ami.ami.id != "" ? data.aws_ami.ami.id : module.ami.ami_id
  image_id      = data.aws_ami.ami.id
  instance_type = var.instance_type
  user_data     = base64encode(local.startup)
  key_name      = var.ssh_keypair
  iam_instance_profile {
    name = var.vault.mode == "server" ? module.iam_instance_profile_vault_server.name : module.iam_instance_profile.name
  }
  network_interfaces {
    associate_public_ip_address = var.associate_public_ips
    security_groups = [var.security_group_id]
    delete_on_termination = true
  }

  tags = {
    ResourceGroup = var.namespace
  }
}

resource "aws_autoscaling_group" "server" {
  name                      = local.namespace
  health_check_grace_period = 900
  health_check_type         = "ELB"
  target_group_arns         = var.target_group_arns
  default_cooldown          = 300
  min_size                  = var.instance_count
  max_size                  = var.nomad.mode == "client" ? var.max_instance_count : var.instance_count
  vpc_zone_identifier       = var.associate_public_ips ? var.vpc.public_subnets : var.vpc.private_subnets
  launch_template {
    id      = aws_launch_template.server.id
    version = aws_launch_template.server.latest_version
  }
  tags = [
    {
      key                 = "ResourceGroup"
      value               = var.namespace
      propagate_at_launch = true
    },
    {
      key                 = "Name"
      value               = local.namespace
      propagate_at_launch = true
    }
  ]
  count = var.instance_count != 0 ? 1 : 0
}

data "aws_instances" "instances" {
  depends_on = [aws_autoscaling_group.server]
  count = var.associate_public_ips && var.instance_count != 0 ? 1 : 0
  instance_tags = {
    ResourceGroup = var.namespace
    Name = local.namespace
  }
  instance_state_names = ["running", "pending"]
}

resource "aws_autoscaling_policy" "nomad_clients_autoscaling" {
  name                   = "autoscaling-nomad-clients"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.server[count.index].name
  count = var.nomad.mode == "client" ? 1 : 0
}

resource "aws_cloudwatch_metric_alarm" "nomad_clients_metric" {
  alarm_name          = "cloudwatch-metric-nomad-clients"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "Job summary"
  namespace           = "Nomad"
  period              = "30"
  statistic           = "Average"
  threshold           = "1"

  dimensions = {
    Status = "Queued"
  }

  alarm_description = "This metric monitors the number of queued jobs"
  alarm_actions     = [aws_autoscaling_policy.nomad_clients_autoscaling[count.index].arn]

  depends_on = [aws_autoscaling_policy.nomad_clients_autoscaling]
  count = var.nomad.mode == "client" ? 1 : 0
}