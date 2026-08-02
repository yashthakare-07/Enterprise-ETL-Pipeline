output "s3_bucket_name" {
  description = "Name of the raw data ingestion S3 bucket"
  value       = aws_s3_bucket.raw_data_bucket.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB processed data table"
  value       = aws_dynamodb_table.etl_table.name
}

output "athena_results_bucket" {
  description = "S3 bucket where Athena stores query results"
  value       = aws_s3_bucket.athena_results.id
}