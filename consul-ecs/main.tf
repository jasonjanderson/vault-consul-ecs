### Variables ###
variable "application" {
  default = "devops"
}

variable "environment" {
  default = "dev"
}

variable "role" {
  default = "consul"
}

variable "ecs_security_group_id" {}
variable "alb_security_group_id" {}
variable "ecs_cluster_id" {}
variable "alb_arn" {}
variable "vpc_id" {}

## #Main ###
data "template_file" "container_definitions" {
  template = "${file("${path.module}/task.json")}"

  vars {
    log_group = "${aws_cloudwatch_log_group.log_group.name}"
  }
}

resource "aws_security_group_rule" "rpc" {
  security_group_id        = "${var.ecs_security_group_id}"
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  self = true
}

resource "aws_security_group_rule" "gossip_lan" {
  security_group_id        = "${var.ecs_security_group_id}"
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "tcp"
  self = true
}

resource "aws_security_group_rule" "http_api" {
  security_group_id        = "${var.ecs_security_group_id}"
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  self = true
}

resource "aws_security_group_rule" "dns" {
  security_group_id        = "${var.ecs_security_group_id}"
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "tcp"
  self = true
}

resource "aws_ecs_task_definition" "consul" {
  family                = "consul"
  container_definitions = "${data.template_file.container_definitions.rendered}"
  network_mode = "host"

  volume {
    name      = "consul_config"
    host_path = "/data/consul/config"
  }
  volume {
    name      = "consul_data"
    host_path = "/data/consul/data"
  }
}

resource "aws_ecs_service" "consul" {
  name            = "consul"
  cluster         = "${var.ecs_cluster_id}"
  task_definition = "${aws_ecs_task_definition.consul.arn}"
  desired_count   = 3
  iam_role        = "${aws_iam_role.role.arn}"
  depends_on      = ["aws_iam_role_policy_attachment.policy"]

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    container_name = "consul"
    container_port = 8500
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "${var.application}-${var.environment}-${var.role}"
}

### Outputs ###
