# 1. DynamoDB Table for Processed Telemetry
resource "aws_dynamodb_table" "etl_table" {
  name         = "EnterpriseETLRecords"
  billing_mode = "PAY_PER_REQUEST" # Serverless on-demand pricing (Free Tier eligible)
  hash_key     = "record_id"
  range_key    = "timestamp"

  attribute {
    name = "record_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Environment = "Production"
    Project     = "EnterpriseETL"
  }
}
