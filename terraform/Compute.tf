# 1. IAM Role for Lambda
resource "aws_iam_role" "etl_lambda_role" {
  name = "enterprise_etl_lambda_role_${random_id.bucket_suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# 2. IAM Policy for S3, SQS, and CloudWatch
resource "aws_iam_role_policy" "etl_lambda_policy" {
  name = "enterprise_etl_lambda_policy"
  role = aws_iam_role.etl_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_data_bucket.arn,
          "${aws_s3_bucket.raw_data_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:BatchWriteItem" # <-- Add this permission
        ]
        Resource = aws_dynamodb_table.etl_table.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.etl_table.arn
      }
    ]
  })
}

# 3. Zip the Python code 
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/etl_processor.zip"
}

# 4. The Lambda Function
resource "aws_lambda_function" "etl_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "EnterpriseETLProcessor"
  role             = aws_iam_role.etl_lambda_role.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.etl_table.name
    }
  }
}

# 5. SQS to Lambda Trigger
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main_queue.arn
  function_name    = aws_lambda_function.etl_processor.arn
  batch_size       = 10
}