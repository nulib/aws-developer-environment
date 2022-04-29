resource "aws_lambda_layer_version" "exiftool" {
  s3_bucket           = "nul-public"
  s3_key              = "exiftool_lambda_layer.zip"
  layer_name          = "exiftool"
  compatible_runtimes = ["nodejs14.x"]
  description         = "exiftool runtime for nodejs lambdas"
}

resource "aws_lambda_layer_version" "ffmpeg" {
  s3_bucket           = "nul-public"
  s3_key              = "ffmpeg.zip"
  layer_name          = "ffmpeg"
  compatible_runtimes = ["nodejs14.x"]
  description         = "FFMPEG runtime for nodejs lambdas"
}

resource "aws_lambda_layer_version" "mediainfo" {
  s3_bucket           = "nul-public"
  s3_key              = "mediainfo_lambda_layer.zip"
  layer_name          = "mediainfo"
  compatible_runtimes = ["nodejs14.x"]
  description         = "mediainfo binaries for nodejs lambdas from https://mediaarea.net/en/MediaInfo/Download/Lambda"
}

locals {
  pipeline = {
    digester = {
      source        = "digester"
      description   = "Function to calcuate the sha256 digest of an S3 object"
      memory        = 1024
      timeout       = 240
    }

    tiff = {
      source        = "pyramid-tiff"
      description   = "Function to create a pyramid tiff from an S3 object and save it to an S3 bucket"
      memory        = 8192
      timeout       = 240
      
      environment = {
        NODE_OPTIONS        = "--max-old-space-size=8192"
        VIPS_DISC_THRESHOLD = "3500m"
      }
    }

    exif = {
      source              = "exif"
      description         = "Function to extract technical metadata from an A/V S3 object"
      ephemeral_storage   = 8192
      memory              = 768
      timeout             = 120

      environment = {
        EXIFTOOL = "/opt/bin/exiftool"
      }
      
      layers = [
        "arn:aws:lambda:us-east-1:652718333417:layer:perl-5_30-layer:1",
        aws_lambda_layer_version.exiftool.arn
      ]
    }

    mediainfo = {
      source        = "mediainfo"
      description   = "Function to extract the mime-type from an S3 object"
      memory        = 512
      timeout       = 240

      environment = {
        MEDIAINFO_PATH = "/opt/bin/mediainfo"
      }

      layers      = [aws_lambda_layer_version.mediainfo.arn]
    }

    mime_type = {
      source        = "mime-type"
      description   = "Function to generate a poster image with an offset from an S3 video"
      memory        = 512
      timeout       = 120
    }

    frame_extractor = {
      source        = "frame-extractor"
      description   = "Function that receives S3 upload notification and triggers fixity step function execution"
      memory        = 1024
      timeout       = 240
      layers        = [aws_lambda_layer_version.ffmpeg.arn]
    }
  }
}

resource "aws_iam_role" "pipeline_lambda_role" {
  name    = "${local.project}-pipeline-lambda-role"
  path    = local.iam_path

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Component = "pipeline"
  }
}

resource "aws_iam_role_policy_attachment" "pipeline_lambda_basic_execution" {
  role          = aws_iam_role.pipeline_lambda_role.name
  policy_arn    = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}

module "pipeline_lambda" {
  for_each    = local.pipeline
  source      = "github.com/nulib/terraform-aws-lambda?ref=build-in-docker-with-npm-arguments"
  # source      = ""terraform-aws-modules/lambda/aws""
  # version     = "~> 3.1"
  
  function_name             = "${local.project}-${each.value.source}"
  build_in_docker           = true
  description               = each.value.description
  handler                   = "index.handler"
  ephemeral_storage_size    = contains(keys(each.value), "ephemeral_storage") ? each.value.ephemeral_storage : 512
  memory_size               = each.value.memory
  runtime                   = "nodejs14.x"
  timeout                   = each.value.timeout
  publish                   = true
  create_role               = false
  lambda_role               = aws_iam_role.pipeline_lambda_role.arn
  
  environment_variables   = contains(keys(each.value), "environment") ? each.value.environment : {}
  layers                  = contains(keys(each.value), "layers") ? each.value.layers : []

  source_path = "${var.lambda_path}/${each.value.source}"

  tags = {
    Component = "pipeline"
  }
}

