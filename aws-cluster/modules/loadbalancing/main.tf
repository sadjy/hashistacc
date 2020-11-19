resource "random_string" "rand" {
  length  = 8
  special = false
  upper   = false
}

locals {
  rand = random_string.rand.result
}

resource "aws_lb" "consul_lb" {
  name            = "${var.namespace}-consul"
  internal        = false
  subnets         = var.vpc.public_subnets
  security_groups = [var.sg.consul_lb]
}

resource "aws_lb_target_group" "consul_ui" {
  name     = "${local.rand}-consul-ui"
  port     = 8500
  protocol = "HTTP"
  vpc_id   = var.vpc.vpc_id

  health_check {
    path = "/v1/status/leader"
  }

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = {
    ResourceGroup = var.namespace
  }
}

resource "aws_lb_listener" "consul_ui" {
  load_balancer_arn = aws_lb.consul_lb.arn
  port              = "8500"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.consul_ui.arn
    type             = "forward"
  }
}

resource "aws_lb" "nomad_lb" {
  name            = "${var.namespace}-nomad"
  internal        = false
  subnets         = var.vpc.public_subnets
  security_groups = [var.sg.nomad_lb]
}

resource "aws_lb_target_group" "nomad_ui" {
  name     = "${local.rand}-nomad-ui"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = var.vpc.vpc_id

  health_check {
    path = "/v1/agent/self"
    matcher = "200-404"
  }

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = {
    ResourceGroup = var.namespace
  }
}

resource "aws_lb_listener" "nomad_ui" {
  load_balancer_arn = aws_lb.nomad_lb.arn
  port              = "4646"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.nomad_ui.arn
    type             = "forward"
  }
}

resource "aws_lb" "fabio_lb" {
  name            = "${var.namespace}-fabio"
  internal        = false
  subnets         = var.vpc.public_subnets
  load_balancer_type = "network"
}

resource "aws_lb_target_group" "fabio_ui" {
  name     = "${local.rand}-fabio-ui"
  port     = 9998
  protocol = "TCP"
  vpc_id   = var.vpc.vpc_id

  health_check {
    port = 4646
  }
  
  tags = {
    ResourceGroup = var.namespace
  }
}

resource "aws_lb_listener" "fabio_ui" {
  load_balancer_arn = aws_lb.fabio_lb.arn
  port              = "9998"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.fabio_ui.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "fabio_lb" {
  name     = "${local.rand}-fabio-lb"
  port     = 9999
  protocol = "TCP"
  vpc_id   = var.vpc.vpc_id

  tags = {
    ResourceGroup = var.namespace
  }

  health_check {
    port = 4646
  }
}

resource "aws_lb_listener" "fabio_lb" {
  load_balancer_arn = aws_lb.fabio_lb.arn
  port              = "9999"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.fabio_lb.arn
    type             = "forward"
  }
}

resource "aws_lb" "vault_lb" {
  name            = "${var.namespace}-vault"
  internal        = false
  subnets         = var.vpc.public_subnets
  security_groups = [var.sg.vault_lb]
}

resource "aws_lb_target_group" "vault_api" {
  name     = "${local.rand}-vault-api"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = var.vpc.vpc_id

  health_check {
    path = "/v1/sys/health"
    matcher = "200,429,472"
  }

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }
  
  tags = {
    ResourceGroup = var.namespace
  }
}

resource "aws_lb_listener" "vault_api" {
  load_balancer_arn = aws_lb.vault_lb.arn
  port              = "8200"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.vault_api.arn
    type             = "forward"
  }
}
