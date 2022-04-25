data "aws_iam_role" "task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_ecs_task_definition" "ldap" {
  family = "ldap"
  
  container_definitions = jsonencode([{
    name                = "ldap"
    image               = "${aws_ecr_repository.dev_repository.repository_url}:ldap"
    essential           = true
    cpu                 = 256
    memoryReservation   = 512

    portMappings = [
      {hostPort = 389, containerPort = 389}
    ]

    readonlyRootFilesystem = false

    logConfiguration = {
      logDriver = "awslogs"
      options   = {
        awslogs-group         = aws_cloudwatch_log_group.dev_environment.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "ldap"
      }
    }

    healthCheck = {
      command  = ["CMD", "echo",  "",  "|", "nc", "localhost", "389"]
      interval = 30
      retries  = 3
      timeout  = 5
    }
  }])

  execution_role_arn       = data.aws_iam_role.task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
}

resource "aws_ecs_cluster" "dev_environment" {
  name = local.project
}

resource "aws_security_group" "ldap" {
  name        = "${local.project}-ldap"
  description = "LDAP Server"
  vpc_id      = module.vpc.vpc_id

 ingress {
    description      = "LDAP from VPC"
    from_port        = 389
    to_port          = 389
    protocol         = "tcp"
    cidr_blocks      = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_service" "ldap" {
  name                = "ldap"
  cluster             = aws_ecs_cluster.dev_environment.id
  desired_count       = 1
  launch_type         = "FARGATE"
  platform_version    = "1.4.0"
  task_definition     = aws_ecs_task_definition.ldap.arn

  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    security_groups  = [aws_security_group.ldap.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.ldap.arn
    port         = 389
  }
}

resource "aws_service_discovery_service" "ldap" {
  name = "ldap"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "SRV"
    }

    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}
