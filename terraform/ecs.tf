resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "dependencytrack" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "apiserver"
      image     = var.apiserver_image
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "ALPINE_DATABASE_MODE",   value = "external" },
        { name = "ALPINE_DATABASE_URL",    value = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.db_name}?sslmode=verify-full" },
        { name = "ALPINE_DATABASE_DRIVER", value = "org.postgresql.Driver" }
      ]
      secrets = [
        { name = "ALPINE_DATABASE_USERNAME", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::" },
        { name = "ALPINE_DATABASE_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::" }
      ]
      memory = 3072
      cpu    = 512
      mountPoints = [
        { sourceVolume = "dtrack-data", containerPath = "/data", readOnly = false }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://127.0.0.1:8080/health || exit 1"]
        interval    = 30
        timeout     = 3
        retries     = 3
        startPeriod = 60
      }
      linuxParameters = { initProcessEnabled = true }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "apiserver"
        }
      }
    },
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true
      portMappings = [
        { containerPort = 8081, protocol = "tcp" }
      ]
      environment = [
        { name = "API_BASE_URL", value = var.api_domain }
      ]
      memory = 512
      cpu    = 256
      dependsOn = [
        { containerName = "apiserver", condition = "HEALTHY" }
      ]
      linuxParameters = { initProcessEnabled = true }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "frontend"
        }
      }
    },
    {
      name      = "trivy"
      image     = "aquasec/trivy:0.69.0"
      essential = false
      command   = ["server", "--listen", "127.0.0.1:8082", "--token", var.trivy_token]
      portMappings = [
        { containerPort = 8082, protocol = "tcp" }
      ]
      memory = 512
      cpu    = 256
      linuxParameters = { initProcessEnabled = true }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "trivy"
        }
      }
    }
  ])

  volume {
    name = "dtrack-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.dtrack.id
      root_directory     = "/data"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.dtrack.id
        iam             = "ENABLED"
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_service" "dependencytrack" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dependencytrack.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.apiserver.arn
    container_name   = "apiserver"
    container_port   = 8080
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 8081
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Environment = var.environment
  }
}
