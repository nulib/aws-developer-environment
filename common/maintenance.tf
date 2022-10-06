data "aws_iam_role" "ssm_service_role" {
  name = "AWSServiceRoleForAmazonSSM"
}

resource "aws_iam_role" "ide_backup" {
  name = "${local.project}-ide-backup"
  path = local.iam_path
  
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "ssm.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name   = "allow-backup-tasks"
    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          Sid       = "0"
          Effect    = "Allow"
          Action    = "ssm:SendCommand"
          Resource  = ["arn:aws:ssm:*:*:document/*"]
        },
        {
          Sid       = "1"
          Effect    = "Allow"
          Action    = ["ec2:DescribeInstanceStatus"]
          Resource  = ["*"]
        },
        {
          Sid       = "2"
          Effect    = "Allow"
          Action    = [
            "ec2:StartInstances",
            "ec2:StopInstances",
            "ssm:SendCommand"
          ]
          Resource  = ["arn:aws:ec2:${local.regional_id}:instance/*"]
          Condition =  {
            StringEquals = {
              "aws:ResourceTag/Project" = local.project
            }
          }
        }
      ]
    })
  }
}

resource "aws_ssm_maintenance_window" "ide_maintenance" {
  name                          = "${local.project}-backup"
  description                   = "Run home directory backup on all developer environment instances"
  duration                      = 1
  cutoff                        = 0
  schedule                      = "cron(0 0 23 ? * FRI *)"
  schedule_timezone             = "America/Chicago"
  allow_unassociated_targets    = true
  enabled                       = true
}

resource "aws_ssm_maintenance_window_target" "ide_instances" {
  window_id       = aws_ssm_maintenance_window.ide_maintenance.id
  name            = "${aws_ssm_maintenance_window.ide_maintenance.name}-targets"
  description     = "All Developer IDEs"
  resource_type   = "RESOURCE_GROUP"

  targets {
    key       = "resource-groups:Name"
    values    = [aws_resourcegroups_group.dev_environment.name]
  }

  targets {
    key       = "resource-groups:ResourceTypeFilters"
    values    = ["AWS::EC2::Instance"]
  }
}

resource "aws_ssm_maintenance_window_task" "start_instance" {
  window_id         = aws_ssm_maintenance_window.ide_maintenance.id
  task_arn          = "AWS-StartEC2Instance"
  task_type         = "AUTOMATION"
  service_role_arn  = data.aws_iam_role.ssm_service_role.arn
  priority          = 10
  max_concurrency   = 5
  max_errors        = 5

  targets {
    key       = "WindowTargetIds"
    values    = [aws_ssm_maintenance_window_target.ide_instances.id]
  }

  task_invocation_parameters {
    automation_parameters {
      parameter {
        name    = "InstanceId"
        values  = ["{{RESOURCE_ID}}"]
      }

      parameter {
        name    = "AutomationAssumeRole"
        values  = [aws_iam_role.ide_backup.arn]
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "run_backup" {
  window_id         = aws_ssm_maintenance_window.ide_maintenance.id
  task_arn          = "AWS-RunShellScript"
  task_type         = "RUN_COMMAND"
  service_role_arn  = data.aws_iam_role.ssm_service_role.arn
  priority          = 20
  max_concurrency   = 5
  max_errors        = 1

  targets {
    key       = "WindowTargetIds"
    values    = [aws_ssm_maintenance_window_target.ide_instances.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      service_role_arn     = aws_iam_role.ide_backup.arn
      parameter {
        name = "commands"
        values = [
          "sudo -Hiu ec2-user sh -c \"cd /home/ec2-user/.nul-rdc-devtools && git pull origin && bin/backup-ide backup\"",
          "shutdown -h 15"
        ]
      }
    }
  }
}
