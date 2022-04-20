resource "aws_ecr_repository" "dev_repository" {
  name                    = local.name
  image_tag_mutability    = "MUTABLE"
  tags                    = local.tags
}

resource "aws_ecr_lifecycle_policy" "nulib_image_expiration" {
  repository  = aws_ecr_repository.dev_repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 2 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 2
        }
        action = {
          type        = "expire"
        }
      }
    ]
  })
}

