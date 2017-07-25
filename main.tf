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

variable "instance_type" {
  description = "The instance type to use, e.g t2.small"
  default     = "t2.micro"
}

variable "min_size" {
  description = "Minimum instance count"
  default     = 5
}

variable "max_size" {
  description = "Maxmimum instance count"
  default     = 5
}

variable "desired_capacity" {
  description = "Desired instance count"
  default     = 5
}

variable "key_name" {
  description = "SSH key name to use"
  default     = "key"
}

variable "instance_ebs_optimized" {
  description = "When set to true the instance will be launched with EBS optimized turned on"
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  default     = 25
}

variable "docker_volume_size" {
  description = "Attached EBS volume size in GB"
  default     = 25
}

## #Main ###
provider "aws" {
  region  = "us-east-1"

}

data "aws_vpc" "current" {
default = true
}

data "aws_subnet_ids" "private" {
  vpc_id = "${data.aws_vpc.current.id}"

  tags {
    Type = "private"
  }
}

module "ecs_cluster" {
  source = "../ecs-cluster"

  application            = "${var.application}"
  environment            = "${var.environment}"
  role                   = "${var.role}"
  vpc_id                 = "${data.aws_vpc.current.id}"
  subnet_ids             = "${data.aws_subnet_ids.private.ids}"
  instance_type          = "${var.instance_type}"
  min_size               = "${var.min_size}"
  max_size               = "${var.max_size}"
  desired_capacity       = "${var.desired_capacity}"
  key_name               = "${var.key_name}"
  root_volume_size       = "${var.root_volume_size}"
  docker_volume_size     = "${var.docker_volume_size}"
  instance_ebs_optimized = "${var.instance_ebs_optimized}"
}

resource "aws_alb" "alb" {
  name            = "${var.application}-${var.environment}-${var.role}"
  internal        = true
  subnets         = ["${data.aws_subnet_ids.private.ids}"]
  security_groups = ["${aws_security_group.alb.id}"]
}

module "consul" {
  source = "./consul-ecs"

  alb_arn               = "${aws_alb.alb.arn}"
  alb_security_group_id = "${aws_security_group.alb.id}"
  ecs_cluster_id        = "${module.ecs_cluster.id}"
  ecs_security_group_id = "${module.ecs_cluster.security_group_id}"
  vpc_id                = "${data.aws_vpc.current.id}"
}


module "vault" {
  source = "./vault-ecs"

  alb_arn               = "${aws_alb.alb.arn}"
  alb_security_group_id = "${aws_security_group.alb.id}"
  ecs_cluster_id        = "${module.ecs_cluster.id}"
  ecs_security_group_id = "${module.ecs_cluster.security_group_id}"
  vpc_id                = "${data.aws_vpc.current.id}"
  alb_address = "${aws_alb.alb.dns_name}"
}

module "vault-ui" {
  source = "./vault-ui-ecs"

  alb_arn               = "${aws_alb.alb.arn}"
  alb_security_group_id = "${aws_security_group.alb.id}"
  ecs_cluster_id        = "${module.ecs_cluster.id}"
  ecs_security_group_id = "${module.ecs_cluster.security_group_id}"
  vpc_id                = "${data.aws_vpc.current.id}"
  alb_address = "${aws_alb.alb.dns_name}"
}


resource "aws_security_group" "alb" {
  name        = "${var.application}-${var.environment}-${var.role}-alb"
  vpc_id      = "${data.aws_vpc.current.id}"
  description = "Allows traffic to/from ECS clusters ALB"
}

### Outputs ###
output "alb_fqdn" {
  value = "${aws_alb.alb.dns_name}"
}
