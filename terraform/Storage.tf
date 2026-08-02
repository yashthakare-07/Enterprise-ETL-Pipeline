# 1. Define a random string to ensure unique bucket names globally
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 2. Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "dlq" {
  name                      = "enterprise-etl-dlq"
  message_retention_seconds = 1209600 # 14 days
}

# 3. Main SQS Queue
resource "aws_sqs_queue" "main_queue" {
  name                       = "enterprise-etl-queue"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# 4. Queue Policy (Allows S3 to send messages to SQS)
resource "aws_sqs_queue_policy" "s3_to_sqs_policy" {
  queue_url = aws_sqs_queue.main_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.main_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.raw_data_bucket.arn
          }
        }
      }
    ]
  })
}

# 5. S3 Bucket for Raw Data Uploads
resource "aws_s3_bucket" "raw_data_bucket" {
  bucket = "enterprise-etl-raw-data-${random_id.bucket_suffix.hex}"
}

# 6. S3 Bucket Notification (Triggers SQS on upload)
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.raw_data_bucket.id

  queue {
    queue_arn = aws_sqs_queue.main_queue.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.s3_to_sqs_policy]
}

# 7. Athena Query Results Bucket
resource "aws_s3_bucket" "athena_results" {
  bucket = "enterprise-etl-athena-results-${random_id.bucket_suffix.hex}"
}