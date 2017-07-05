### Variables ###
variable "application" {
  default = "devops"
}

variable "environment" {
  default = "dev"
}

variable "role" {
  default = "vault"
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

data "aws_alb" "alb" {
  arn = "${var.alb_arn}"
}

resource "aws_security_group_rule" "http_api" {
  security_group_id = "${var.ecs_security_group_id}"
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  self              = true
}

resource "aws_ecs_task_definition" "vault" {
  family                = "vault"
  container_definitions = "${data.template_file.container_definitions.rendered}"
  network_mode          = "host"

  volume {
    name      = "vault_config"
    host_path = "/efs/vault/config"
  }

  volume {
    name      = "vault_logs"
    host_path = "/data/vault/logs"
  }
}

resource "aws_ecs_service" "vault" {
  name            = "vault"
  cluster         = "${var.ecs_cluster_id}"
  task_definition = "${aws_ecs_task_definition.vault.arn}"
  desired_count   = 2
  iam_role        = "${aws_iam_role.role.arn}"
  depends_on      = ["aws_iam_role_policy_attachment.policy"]

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    container_name   = "vault"
    container_port   = 8200
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "${var.application}-${var.environment}-${var.role}"
}

### Outputs ###

