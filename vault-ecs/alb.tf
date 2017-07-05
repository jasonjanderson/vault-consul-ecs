resource "aws_alb_target_group" "target_group" {
  name     = "${var.application}-${var.environment}-${var.role}"
  port     = 8200
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"

  health_check {
    path = "/sys/health"
    port = 8200
  }
}

resource "aws_alb_listener" "alb_listener_https" {
  load_balancer_arn = "${var.alb_arn}"
  port              = "8200"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.target_group.arn}"
    type             = "forward"
  }
}

resource "aws_security_group_rule" "listener_http_api" {
  security_group_id = "${var.ecs_security_group_id}"

  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = "${var.alb_security_group_id}"
}

resource "aws_security_group_rule" "alb_http_api" {
  security_group_id = "${var.alb_security_group_id}"

  type        = "ingress"
  from_port   = 8200
  to_port     = 8200
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
