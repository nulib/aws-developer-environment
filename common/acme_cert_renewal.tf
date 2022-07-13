resource "aws_cloudwatch_log_group" "acme_cert_logs" {
  name                = "/ecs/acme-cert"
  retention_in_days   = 3
}

data "aws_iam_policy_document" "acme_cert_policy" {
  statement {
    sid       = "AcmeS3ListAccess"
    effect    = "Allow"
    actions   = ["s3:List*"]
    resources = [
      "arn:aws:s3:::${var.acme_cert_state_store.bucket}",
      "arn:aws:s3:::${var.acme_cert_state_store.bucket}/*"
    ]
  }
  statement {
    sid       = "AcmeStateAccess"
    effect    = "Allow"
    actions   = ["s3:Get*", "s3:Put*"]
    resources = ["arn:aws:s3:::${var.acme_cert_state_store.bucket}/${var.acme_cert_state_store.key}"]
  }

  statement {
    sid       = "AcmeSecretsAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:PutSecretValue"]
    resources = [aws_secretsmanager_secret.ssl_certificate.id]
  }

  statement {
    sid       = "AcmeDnsZoneAccess"
    effect    = "Allow"
    actions   = ["route53:ListHostedZones"]
    resources = ["*"]
  }

  statement {
    sid       = "AcmeDnsRecordAccess"
    effect    = "Allow"
    actions   = [
      "route53:ListResourceRecordSets", 
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${aws_route53_zone.hosted_zone.zone_id}"
    ]
  }
}

resource "aws_iam_policy" "acme_cert_task_policy" {
  path    = local.iam_path
  name    = "${local.project}-acme-cert"
  policy  = data.aws_iam_policy_document.acme_cert_policy.json
}

resource "aws_iam_role" "acme_cert_task_role" {
  path    = local.iam_path
  name    = "${local.project}-acme-cert"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "acme_cert" {
  role          = aws_iam_role.acme_cert_task_role.name
  policy_arn    = aws_iam_policy.acme_cert_task_policy.arn
}

resource "aws_ecs_task_definition" "acme_cert" {
  family = "acme-cert"
  
  container_definitions = jsonencode([{
    name                = "acme-cert"
    image               = "${aws_ecr_repository.dev_repository.repository_url}:acme-cert"
    essential           = true
    cpu                 = 256
    memoryReservation   = 512

    environment = [
      { name  = "ACME_DATA_STORE", value = "s3://${var.acme_cert_state_store.bucket}/${var.acme_cert_state_store.key}" },
      { name  = "CERT_DOMAIN",     value = var.hosted_zone_name },
      { name  = "SECRET_PATH",     value = "${local.project}/config/wildcard_ssl" }
    ]
    
    readonlyRootFilesystem = false

    logConfiguration = {
      logDriver = "awslogs"
      options   = {
        awslogs-group         = aws_cloudwatch_log_group.dev_environment.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "acme-cert"
      }
    }
  }])

  task_role_arn            = aws_iam_role.acme_cert_task_role.arn
  execution_role_arn       = data.aws_iam_role.task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
}

resource "aws_iam_role" "allow_cert_renewal" {
  path    = local.iam_path
  name    = "${local.project}-allow-cert-renewal"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

data "aws_iam_policy_document" "allow_cert_renewal" {
  statement {
    sid       = "AllowPassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [
      aws_ecs_task_definition.acme_cert.execution_role_arn, 
      aws_ecs_task_definition.acme_cert.task_role_arn
    ]
  }

  statement {
    sid       = "AllowRunTask"
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.acme_cert.arn]
  }
}

resource "aws_iam_policy" "allow_cert_renewal" {
  path    = local.iam_path
  name    = "${local.project}-allow-cert-renewal"
  policy  = data.aws_iam_policy_document.allow_cert_renewal.json
}

resource "aws_iam_role_policy_attachment" "cert_renewal" {
  role          = aws_iam_role.allow_cert_renewal.name
  policy_arn    = aws_iam_policy.allow_cert_renewal.arn
}

resource "aws_cloudwatch_event_rule" "cert_renewal" {
  name        = "${local.project}-renew-developer-certificate"
  description = "Renew developer certificate every 45 days"

  schedule_expression = "rate(45 days)"
}

data "aws_ecs_cluster" "default" {
  cluster_name = "default"
}

resource "aws_cloudwatch_event_target" "cert_renewal" {
  rule        = aws_cloudwatch_event_rule.cert_renewal.name
  target_id   = "RenewDeveloperCertificate"
  arn         = data.aws_ecs_cluster.default.arn
  role_arn    = aws_iam_role.allow_cert_renewal.arn

  ecs_target {
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"
    task_definition_arn = aws_ecs_task_definition.acme_cert.arn
    propagate_tags      = "TASK_DEFINITION"

    network_configuration {
      assign_public_ip    = true
      security_groups     = [module.vpc.default_security_group_id]
      subnets             = module.vpc.public_subnets
    }   
  }
}

