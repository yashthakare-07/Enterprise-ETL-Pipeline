import json
import os
import logging
from decimal import Decimal
import boto3  # type: ignore[import-not-found]
from urllib.parse import unquote_plus
from pydantic import BaseModel, ValidationError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

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
    if isinstance(obj, list):
        return [float_to_decimal(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: float_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    return obj

def lambda_handler(event, context):
    logger.info("Enterprise ETL Worker (DynamoDB Mode) initiated.")
    batch_item_failures = []

    for record in event.get('Records', []):
        processed_count = 0
        failed_count = 0
        message_id = record.get('messageId')
        
        try:
            body = json.loads(record['body'])

            if 'Event' in body and body['Event'] == 's3:TestEvent':
                continue

            for s3_record in body.get('Records', []):
                bucket_name = s3_record['s3']['bucket']['name']
                raw_key = s3_record['s3']['object']['key']
                object_key = unquote_plus(raw_key)

                logger.info(f"Fetching object s3://{bucket_name}/{object_key}")

                response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
                file_content = response['Body'].read().decode('utf-8')

                data_rows = json.loads(file_content)
                if not isinstance(data_rows, list):
                    data_rows = [data_rows]

                with table.batch_writer() as batch:
                    for row in data_rows:
                        try:
                            validated_data = TelemetryRecord(**row)
                            transformed_dict = validated_data.model_dump()
                            transformed_dict['status'] = transformed_dict['status'].upper()
                            transformed_dict = float_to_decimal(transformed_dict)

                            batch.put_item(Item=transformed_dict)
                            processed_count += 1

                        except ValidationError as ve:
                            logger.error(f"Data Quality Error (Dropped Row): {ve}")
                            failed_count += 1

                logger.info(f"Successfully processed and written {processed_count} rows to DynamoDB for message {message_id}.")

        except Exception as e:
            logger.error(f"Critical processing error on message {message_id}: {e}")
            if message_id:
                batch_item_failures.append({"itemIdentifier": message_id})

    return {
        "batchItemFailures": batch_item_failures
    }