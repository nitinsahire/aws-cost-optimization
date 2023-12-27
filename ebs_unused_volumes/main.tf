provider "aws" {
  region = var.region
}

data "archive_file" "lambda_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code/ebs_unused_volumes"
  output_path = "${path.module}/ebs_unused_volumes/.zip"
}

resource "aws_lambda_function" "ebs_unused_volumes_lambda_function" {
  filename      = data.archive_file.lambda_function_zip.output_path
  function_name = "ebs_unused_volumes_lambda_function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_unused_volumes_lambda_function.function_name
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.invoke_lambda_rule.arn
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for Lambda function"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        "Action" = [
          "ec2:DescribeVolumes"
        ],
        "Resource" = "*",
        "Effect"   = "Allow"
      },
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_cloudwatch_event_rule" "invoke_lambda_rule" {
  name                = "invoke_lambda_rule"
  description         = "Invoke Lambda on schedule"
  schedule_expression = "rate(1 day)"

  depends_on = [aws_lambda_function.ebs_unused_volumes_lambda_function]
}

resource "aws_cloudwatch_event_target" "invoke_lambda_target" {
  target_id = "invoke_lambda_target"
  rule      = aws_cloudwatch_event_rule.invoke_lambda_rule.name
  arn       = aws_lambda_function.ebs_unused_volumes_lambda_function.arn
}
