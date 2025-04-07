import os
import json
import boto3
import requests
from datetime import datetime
from decimal import Decimal
import logging
from botocore.exceptions import ClientError


logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_secret():
    """Fetch API key securely from AWS Secrets Manager"""
    client = boto3.client('secretsmanager')
    try:
        secret = client.get_secret_value(SecretId=os.environ['SECRET_NAME'])
        return secret['SecretString']
    except ClientError as e:
        raise ValueError(f"Secret retrieval error: {e.response['Error']['Code']}")

def fetch_stock_data(symbol, api_key):
    """Fetch daily stock data from Alpha Vantage API with error handling"""
    url = "https://www.alphavantage.co/query"
    params = {
        "function": "TIME_SERIES_DAILY",
        "symbol": symbol,
        "apikey": api_key,
        "outputsize": "compact"
    }

    try:
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()

        # Check for known Alpha Vantage error messages
        if "Error Message" in data:
            raise ValueError(f"Alpha Vantage Error: {data['Error Message']}")
        if "Note" in data:
            raise ValueError(f"API Rate Limit Notice: {data['Note']}")
        if "Time Series (Daily)" not in data or not data["Time Series (Daily)"]:
            raise ValueError("No time series data returned. Possibly invalid symbol or no recent data.")

        return data

    except requests.exceptions.Timeout:
        raise TimeoutError("The request to Alpha Vantage timed out.")
    except requests.exceptions.RequestException as e:
        raise ConnectionError(f"HTTP request failed: {e}")
    except json.JSONDecodeError:
        raise ValueError("Failed to parse JSON response from API.")


def process_data(raw_data):
    """Transform raw API data to a DynamoDB-friendly format"""
    symbol = raw_data["Meta Data"]["2. Symbol"]
    last_refreshed = raw_data["Meta Data"]["3. Last Refreshed"]
    time_series = raw_data["Time Series (Daily)"]

    processed = []
    for date, values in time_series.items():
        processed.append({
            "SymbolDate": f"{symbol}_{date}",  # Partition key
            "Symbol": symbol,
            "Date": date,
            "Open": Decimal(str(values["1. open"])),
            "High": Decimal(str(values["2. high"])),
            "Low": Decimal(str(values["3. low"])),
            "Close": Decimal(str(values["4. close"])),
            "Volume": int(values["5. volume"]),
            "LastRefreshed": last_refreshed
        })
    return processed

def lambda_handler(event, context):

    if "source" in event and event["source"] == "aws.events":
        logger.info("Scheduled execution triggered by EventBridge")

    try:
        # Step 1: Load API Key
        api_key = get_secret()

        # Step 2: Fetch raw data
        raw_data = fetch_stock_data("IBM", api_key)

        # Step 3: Process the data
        processed_data = process_data(raw_data)

        # Step 4: Store raw JSON in S3
        s3 = boto3.client('s3')
        s3.put_object(
            Bucket=os.environ['S3_BUCKET'],
            Key=f"raw/{datetime.now().isoformat()}.json",
            Body=json.dumps(raw_data),
            ContentType='application/json'
        )

        # Step 5: Store processed data in DynamoDB
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(os.environ['DYNAMO_TABLE'])

        with table.batch_writer() as batch:
            for item in processed_data:
                batch.put_item(Item=item)

        message = f"Success: Stored {len(processed_data)} records"
        
        return {
            "statusCode": 200,
            "body": message
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": f"Error: {str(e)}"
        }
