data "aws_iam_role" "task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_ecs_cluster" "dev_environment" {
  name = local.project
}

resource "aws_security_group" "samvera_stack_service" {
  name        = "${local.project}-solr-service"
  description = "Fedora/Solr Service Security Group"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "samvera_stack_service_egress" {
  security_group_id   = aws_security_group.samvera_stack_service.id
  type                = "egress"
  from_port           = 0
  to_port             = 65535
  protocol            = "tcp"
  cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "samvera_stack_service_ingress" {
  for_each            = toset(["6379", "8080", "8983", "9983"])
  security_group_id   = aws_security_group.samvera_stack_service.id
  type                = "ingress"
  from_port           = each.key
  to_port             = each.key
  protocol            = "tcp"
  cidr_blocks         = ["0.0.0.0/0"]
}

resource "aws_s3_bucket" "fedora_binaries" {
  bucket      = "${local.project}-shared-fcrepo-binaries"
}

resource "aws_iam_user" "fedora_binary_bucket_user" {
  name = "${local.project}-shared-fcrepo"
  path = "/system/"
}

resource "aws_iam_access_key" "fedora_binary_bucket_access_key" {
  user = aws_iam_user.fedora_binary_bucket_user.name
}

resource "aws_iam_user_policy" "fedora_binary_bucket_user_policy" {
  name = "${local.project}-shared-fcrepo"
  user = aws_iam_user.fedora_binary_bucket_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "1"
        Effect = "Allow"
        Action = ["s3:*"]

        Resource = [
          "${aws_s3_bucket.fedora_binaries.arn}",
          "${aws_s3_bucket.fedora_binaries.arn}/*"
        ]
      }
    ]
  })
}

locals {
  fedora_java_opts = {
    "fcrepo.postgresql.host" = module.aurora_postgresql.cluster_endpoint
    "fcrepo.postgresql.port" = module.aurora_postgresql.cluster_port
    "fcrepo.postgresql.username" = module.aurora_postgresql.cluster_master_username
    "fcrepo.postgresql.password" = module.aurora_postgresql.cluster_master_password
    "aws.accessKeyId" = aws_iam_access_key.fedora_binary_bucket_access_key.id
    "aws.secretKey" = aws_iam_access_key.fedora_binary_bucket_access_key.secret
    "aws.bucket" = aws_s3_bucket.fedora_binaries.id
  }
}

resource "aws_ecs_task_definition" "samvera_stack" {
  family = "${local.project}-samvera-stack"
  
  container_definitions = jsonencode([
    {
      name                = "fcrepo"
      image               = "${data.aws_caller_identity.current_user.id}.dkr.ecr.us-east-1.amazonaws.com/fcrepo4:4.7.5-s3multipart"
      essential           = true
      cpu                 = 768
      environment = [
        { 
          name  = "MODESHAPE_CONFIG",
          value = "classpath:/config/jdbc-postgresql-s3/repository.json"
        },
        {
          name  = "JAVA_OPTIONS",
          value = join(" ", [for key, value in local.fedora_java_opts : "-D${key}=${value}"])
        }
      ]
      portMappings = [
        { hostPort = 8080, containerPort = 8080 }
      ]
      readonlyRootFilesystem = false
      healthCheck = {
        command  = ["CMD-SHELL", "wget -q -O /dev/null --method=OPTIONS http://localhost:8080/rest/"]
        interval = 30
        retries  = 3
        timeout  = 5
      }
    },
    {
      name                = "solrcloud",
      image               = "${data.aws_caller_identity.current_user.id}.dkr.ecr.us-east-1.amazonaws.com/solr:8.11-slim"
      essential           = true
      cpu                 = 1024
      command             = ["solr", "-f", "-cloud"]
      environment = [
        { name = "KAFKA_OPTS",      value = "-Dzookeeper.4lw.commands.whitelist=*" },
        { name = "SOLR_HEAP",       value = "${1024 * 0.9765625}m" }
      ]
      portMappings = [
        { hostPort = 8983, containerPort = 8983 },
        { hostPort = 9983, containerPort = 9983 }
      ]
      readonlyRootFilesystem = false
      healthCheck = {
        command  = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:8983/solr/"]
        interval = 30
        retries  = 3
        timeout  = 5
      }
    },
    {
      name                = "redis",
      image               = "redis"
      essential           = true
      cpu                 = 256
      portMappings = [
        { hostPort = 6379, containerPort = 6379 }
      ]
      mountPoints = [
        { sourceVolume = "fcrepo-data", containerPath = "/data" }
      ]
      readonlyRootFilesystem = false
      healthCheck = {
        command  = ["CMD-SHELL", "redis-cli ping"]
        interval = 30
        retries  = 3
        timeout  = 5
      }
    }
  ])

  volume {
    name = "fcrepo-data"
  }

  task_role_arn            = data.aws_iam_role.task_execution_role.arn
  execution_role_arn       = data.aws_iam_role.task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 2048
  memory                   = 4096
}

resource "aws_ecs_service" "samvera_stack" {
  name                   = "samvera-stack"
  cluster                = aws_ecs_cluster.dev_environment.id
  task_definition        = aws_ecs_task_definition.samvera_stack.arn
  desired_count          = 0
  enable_execute_command = true
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"

  lifecycle {
    ignore_changes          = [desired_count]
  }

  network_configuration {
    security_groups  = [aws_security_group.samvera_stack_service.id]
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.samvera_stack.arn
  }
}

resource "aws_service_discovery_service" "samvera_stack" {
  name = "samvera-stack"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}
