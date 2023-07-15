# create ecs cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name      = "${var.project_name}-cluster"

  setting {
    name    = "containerInsights"
    value   = "disabled"
  }
}

# create cloudwatch log group
resource "aws_cloudwatch_log_group" "log_group" {
  name = "/ecs/${var.project_name}-task-definition"

  lifecycle {
    create_before_destroy = true
  }
}

# create task definition
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                    = "${var.project_name}-task-definition"
  execution_role_arn        = var.ecs_tasks_execution_role_arn
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                       = 2048
  memory                    = 4096

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions     = jsonencode([
    {
      name                  = "${var.project_name}-container"
      image                 = var.container_image
      essential             = true

      portMappings          = [
        {
          containerPort     = 80
          hostPort          = 80
        }
      ]
      
      ulimits = [
        {
          name = "nofile",
          softLimit = 1024000,
          hardLimit = 1024000
        }
      ]

      logConfiguration = {
        logDriver   = "awslogs",
        options     = {
            "awslogs-group"         = aws_cloudwatch_log_group.log_group.name,
            "awslogs-region"        = var.region,
            "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# create ecs service
resource "aws_ecs_service" "ecs_service" {
  name              = "${var.project_name}-service"
  launch_type       = "FARGATE"
  cluster           = aws_ecs_cluster.ecs_cluster.id
  task_definition   = aws_ecs_task_definition.ecs_task_definition.arn
  platform_version  = "LATEST"
  desired_count     = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # task tagging configuration
  enable_ecs_managed_tags            = false
  propagate_tags                     = "SERVICE"

  # vpc and security groups
  network_configuration {
    subnets                 = [var.private_app_subnet_az1_id, var.private_app_subnet_az2_id]
    security_groups         = [var.ecs_security_group_id] 
    assign_public_ip        = false
  }

  # load balancing
  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "${var.project_name}-container"
    container_port   = 80
  }
}