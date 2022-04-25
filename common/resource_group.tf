resource "aws_resourcegroups_group" "dev_environment" {
  name = "${local.project}-resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key = "Project"
          Values = [local.project]
        }
      ]
    })
  }
}