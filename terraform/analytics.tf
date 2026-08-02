# 1. Athena Database for the Data Lake with a unique logical name
resource "aws_glue_catalog_database" "etl_analytics_db" {
  name = "enterprise_etl_catalog_${random_id.bucket_suffix.hex}"
}

# 2. Athena Workgroup for query execution results
resource "aws_athena_workgroup" "etl_workgroup" {
  name = "enterprise_etl_workgroup_${random_id.bucket_suffix.hex}"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }

  tags = {
    Environment = "Production"
  }
}

# 3. Athena External Table for Telemetry Logs
resource "aws_glue_catalog_table" "telemetry_table" {
  database_name = aws_glue_catalog_database.etl_analytics_db.name
  name          = "raw_telemetry_logs"
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"  = "json"
    "compressionType" = "none"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.raw_data_bucket.bucket}/raw/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "record_id"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "device_id"
      type = "string"
    }
    columns {
      name = "sensor_value"
      type = "double"
    }
    columns {
      name = "status"
      type = "string"
    }
  }
}