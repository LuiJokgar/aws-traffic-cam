terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# DynamoDB Table
resource "aws_dynamodb_table" "traffic_state" {
  name         = "traffic-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "stationId"

  attribute {
    name = "stationId"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}

# Secrets Manager
resource "aws_secretsmanager_secret" "api_keys" {
  name = "traffic-cam/api-keys"

  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    OPENWEATHER_API_KEY = var.openweather_api_key
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "traffic-cam-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "traffic-cam-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.traffic_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.api_keys.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "traffic_state_updater" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "traffic-state-updater"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Project = var.project_name
  }
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "scheduler" {
  name                = "traffic-state-scheduler"
  schedule_expression = "rate(1 minute)"

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.scheduler.name
  target_id = "TrafficStateUpdaterTarget"
  arn       = aws_lambda_function.traffic_state_updater.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_state_updater.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler.arn
}

# S3 Bucket for frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "traffic-cam-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

# API Gateway
resource "aws_api_gateway_rest_api" "traffic_api" {
  name = "traffic-cam-api"

  tags = {
    Project = var.project_name
  }
}

resource "aws_api_gateway_resource" "state" {
  rest_api_id = aws_api_gateway_rest_api.traffic_api.id
  parent_id   = aws_api_gateway_rest_api.traffic_api.root_resource_id
  path_part   = "state"
}

resource "aws_api_gateway_method" "get_state" {
  rest_api_id   = aws_api_gateway_rest_api.traffic_api.id
  resource_id   = aws_api_gateway_resource.state.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.traffic_api.id
  resource_id             = aws_api_gateway_resource.state.id
  http_method             = aws_api_gateway_method.get_state.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.traffic_state_updater.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.traffic_state_updater.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.traffic_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.traffic_api.id
  stage_name  = "prod"

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

# Data sources
data "aws_caller_identity" "current" {}