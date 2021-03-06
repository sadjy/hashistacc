output "target_group_arns" {
  value = {
    consul = [
      aws_lb_target_group.consul_ui.arn,
    ]
    nomad = [
      aws_lb_target_group.nomad_ui.arn,
    ]
    vault = [
      aws_lb_target_group.vault_api.arn,
    ]
    fabio = [
      aws_lb_target_group.fabio_ui.arn,
      aws_lb_target_group.fabio_lb.arn,
    ]
  }
}

output "addresses" {
  value = {
    consul_ui = "http://${aws_lb.consul_lb.dns_name}:8500"
    nomad_ui  = "http://${aws_lb.nomad_lb.dns_name}:4646"
    fabio_ui  = "http://${aws_lb.fabio_lb.dns_name}:9998"
    fabio_lb  = "http://${aws_lb.fabio_lb.dns_name}:9999"
    vault_lb  = "http://${aws_lb.vault_lb.dns_name}:8200"
  }
}

output "dns_names" {
  value = {
    consul = aws_lb.consul_lb.dns_name,
    nomad = aws_lb.nomad_lb.dns_name,
    vault = aws_lb.vault_lb.dns_name,
    fabio = aws_lb.fabio_lb.dns_name
  }
}