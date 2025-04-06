# Raw Data S3 Bucket
resource "aws_s3_bucket" "raw_data" {
  bucket_prefix = "alpha-vantage-raw-"
}

resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration { status = "Enabled" }
}


resource "aws_dynamodb_table" "processed_data" {
  name         = "ProcessedStockData"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "SymbolDate"

  attribute {
    name = "SymbolDate"
    type = "S"
  }

  # Global Secondary Index for querying by symbol
  global_secondary_index {
    name            = "SymbolIndex"
    hash_key        = "Symbol"
    projection_type = "ALL"
  }

  attribute {
    name = "Symbol"
    type = "S"
  }
}
