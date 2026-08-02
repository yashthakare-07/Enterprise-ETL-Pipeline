# 1. DynamoDB Table for Processed Telemetry
resource "aws_dynamodb_table" "etl_table" {
  name         = "EnterpriseETLRecords_${random_id.bucket_suffix.hex}"
  billing_mode = "PAY_PER_REQUEST"
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