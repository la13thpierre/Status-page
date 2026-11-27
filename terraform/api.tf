data "archive_file" "reader" {
  type        = "zip"
  source_file = "${path.module}/../Lambda/reader.py"
  output_path = "${path.module}/reader.zip"
}

resource "aws_iam_role" "reader" {
  name               = "status-page-reader"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "reader_logs" {
  role       = aws_iam_role.reader.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "reader_db" {
  statement {
    actions   = ["dynamodb:Query"]
    resources = [aws_dynamodb_table.checks.arn]
  }
}

resource "aws_iam_role_policy" "reader_db" {
  name   = "reader-dynamodb"
  role   = aws_iam_role.reader.id
  policy = data.aws_iam_policy_document.reader_db.json
}

resource "aws_lambda_function" "reader" {
  function_name    = "status-page-reader"
  role             = aws_iam_role.reader.arn
  runtime          = "python3.12"
  handler          = "reader.handler"
  filename         = data.archive_file.reader.output_path
  source_code_hash = data.archive_file.reader.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.checks.name
      SITES      = jsonencode(var.sites)
    }
  }
}

resource "aws_apigatewayv2_api" "status" {
  name          = "status-page-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
  }
}

resource "aws_apigatewayv2_integration" "reader" {
  api_id                 = aws_apigatewayv2_api.status.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.reader.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "status" {
  api_id    = aws_apigatewayv2_api.status.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.reader.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.status.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reader.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.status.execution_arn}/*/*"
}

output "api_url" {
  value = aws_apigatewayv2_api.status.api_endpoint
}