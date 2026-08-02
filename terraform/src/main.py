import json
import os
from decimal import Decimal
import boto3
from urllib.parse import unquote_plus
from pydantic import BaseModel, ValidationError

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE', 'EnterpriseETLRecords')
table = dynamodb.Table(table_name)

class TelemetryRecord(BaseModel):
    record_id: str
    timestamp: str
    device_id: str
    sensor_value: float
    status: str

def float_to_decimal(obj):
    """Recursively convert floats to Decimals for DynamoDB compatibility."""
    if isinstance(obj, list):
        return [float_to_decimal(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: float_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    return obj

def lambda_handler(event, context):
    print("Enterprise ETL Worker (DynamoDB Mode) initiated.")
    processed_count = 0
    failed_count = 0
    
    for record in event.get('Records', []):
        try:
            body = json.loads(record['body'])
            
            if 'Event' in body and body['Event'] == 's3:TestEvent':
                continue
                
            for s3_record in body.get('Records', []):
                bucket_name = s3_record['s3']['bucket']['name']
                
                # Extract and decode the S3 object key
                raw_key = s3_record['s3']['object']['key']
                object_key = unquote_plus(raw_key) 
                
                print(f"Fetching object s3://{bucket_name}/{object_key}")
                
                response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
                file_content = response['Body'].read().decode('utf-8')
                
                data_rows = json.loads(file_content)
                if not isinstance(data_rows, list):
                    data_rows = [data_rows]
                
                # Optimization: Implement DynamoDB Batch Writer
                with table.batch_writer() as batch:
                    for row in data_rows:
                        try:
                            validated_data = TelemetryRecord(**row)
                            
                            # Data Transformation & Decimal conversion for DynamoDB
                            transformed_dict = validated_data.model_dump()
                            transformed_dict['status'] = transformed_dict['status'].upper()
                            transformed_dict = float_to_decimal(transformed_dict)
                            
                            # Write item to DynamoDB batch
                            batch.put_item(Item=transformed_dict)
                            processed_count += 1
                            
                        except ValidationError as ve:
                            print(f"Data Quality Error (Dropped Row): {ve}")
                            failed_count += 1
                
                print(f"Successfully processed and written {processed_count} rows to DynamoDB.")

        except Exception as e:
            print(f"Critical processing error on record: {e}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps({
            "message": "ETL Batch execution completed successfully.",
            "processed_rows": processed_count,
            "failed_rows": failed_count
        })
    }