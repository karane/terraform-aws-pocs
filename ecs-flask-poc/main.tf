terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Parameter Store 
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_region" "current" {}

# ECR -- stores the Flask container image
resource "aws_ecr_repository" "flask" {
  name                 = "ecs-flask-poc"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "flask" {
  name              = "/ecs/ecs-flask-poc"
  retention_in_days = 7
}

# IAM -- lets EC2 instances register with ECS and pull from ECR
resource "aws_iam_role" "ecs_instance" {
  name = "ecs-flask-poc-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "ecs-flask-poc-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

# Task execution role -- used by ECS agent to send logs to CloudWatch
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-flask-poc-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "ecs_instance" {
  name   = "ecs-flask-poc-instance-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "flask" {
  name = "ecs-flask-poc-cluster"
}

# EC2 Auto Scaling Group (container hosts)
resource "aws_launch_template" "ecs" {
  name_prefix   = "ecs-flask-poc-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instance.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.flask.name} >> /etc/ecs/ecs.config
  EOF
  )
}

resource "aws_autoscaling_group" "ecs" {
  name                = "ecs-flask-poc-asg"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# Capacity Provider
resource "aws_ecs_capacity_provider" "flask" {
  name = "flask-poc-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "flask" {
  cluster_name       = aws_ecs_cluster.flask.name
  capacity_providers = [aws_ecs_capacity_provider.flask.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.flask.name
    weight            = 1
  }
}

# Task Definition 
resource "aws_ecs_task_definition" "flask" {
  family             = "ecs-flask-poc-task"
  network_mode       = "bridge"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "flask-app"
      image     = "${aws_ecr_repository.flask.repository_url}:latest"
      essential = true
      memory    = 256
      cpu       = 256
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flask.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "flask"
        }
      }
    }
  ])

}

# ECS Service
resource "aws_ecs_service" "flask" {
  name            = "ecs-flask-poc-service"
  cluster         = aws_ecs_cluster.flask.id
  task_definition = aws_ecs_task_definition.flask.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.flask.name
    weight            = 1
  }

  depends_on = [aws_ecs_cluster_capacity_providers.flask]
}
