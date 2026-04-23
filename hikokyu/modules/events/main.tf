variable "name"        { default = "slabble-events" }
variable "glue_database" { default = "slabble" }

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# S3 bucket: event sink (Firehose writes Parquet here).
# Lifecycle: Standard -> Standard-IA at 30d -> Glacier IR at 180d. Never deleted.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "events" {
  bucket = var.name
}

resource "aws_s3_bucket_public_access_block" "events" {
  bucket                  = aws_s3_bucket.events.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "events" {
  bucket = aws_s3_bucket.events.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "events" {
  bucket = aws_s3_bucket.events.id

  rule {
    id     = "tier-events"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 180
      storage_class = "GLACIER_IR"
    }
  }
}

# -----------------------------------------------------------------------------
# Glue Catalog: database + table for Athena to read Parquet from S3.
# -----------------------------------------------------------------------------

resource "aws_glue_catalog_database" "slabble" {
  name = var.glue_database
}

resource "aws_glue_catalog_table" "events" {
  name          = "events"
  database_name = aws_glue_catalog_database.slabble.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
    classification        = "parquet"
  }

  partition_keys {
    name = "dt"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.events.bucket}/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "schema_version"
      type = "int"
    }
    columns {
      name = "event_id"
      type = "string"
    }
    columns {
      name = "ts"
      type = "string"
    }
    columns {
      name = "server_ts"
      type = "string"
    }
    columns {
      name = "session_id"
      type = "string"
    }
    columns {
      name = "anon_user_id"
      type = "string"
    }
    columns {
      name = "game"
      type = "string"
    }
    columns {
      name = "puzzle_number"
      type = "int"
    }
    columns {
      name = "event_type"
      type = "string"
    }
    columns {
      name = "country"
      type = "string"
    }
    columns {
      name = "props"
      type = "string"
    }
  }
}

# -----------------------------------------------------------------------------
# Firehose IAM role: allows the delivery stream to write to S3 and read Glue.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "firehose" {
  name = "${var.name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "firehose_s3" {
  name = "${var.name}-firehose-s3"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject",
      ]
      Resource = [
        aws_s3_bucket.events.arn,
        "${aws_s3_bucket.events.arn}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "firehose_glue" {
  name = "${var.name}-firehose-glue"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "glue:GetTable",
        "glue:GetTableVersion",
        "glue:GetTableVersions",
      ]
      Resource = [
        "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:catalog",
        "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.slabble.name}",
        "arn:aws:glue:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.slabble.name}/${aws_glue_catalog_table.events.name}",
      ]
    }]
  })
}

# -----------------------------------------------------------------------------
# Firehose delivery stream: JSON -> Parquet, partitioned by dt=YYYY-MM-DD.
# Buffer: 60s or 5 MiB, whichever comes first.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_stream" "firehose_s3" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_kinesis_firehose_delivery_stream" "events" {
  name        = var.name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.events.arn

    prefix              = "dt=!{timestamp:yyyy-MM-dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/dt=!{timestamp:yyyy-MM-dd}/"

    buffering_size     = 64
    buffering_interval = 60
    compression_format = "UNCOMPRESSED" # Parquet's internal compression (SNAPPY) applies

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_s3.name
    }

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }
      output_format_configuration {
        serializer {
          parquet_ser_de {
            compression = "SNAPPY"
          }
        }
      }
      schema_configuration {
        database_name = aws_glue_catalog_database.slabble.name
        table_name    = aws_glue_catalog_table.events.name
        role_arn      = aws_iam_role.firehose.arn
      }
    }
  }
}

output "stream_name" {
  value = aws_kinesis_firehose_delivery_stream.events.name
}

output "stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.events.arn
}

output "bucket_name" {
  value = aws_s3_bucket.events.bucket
}

output "glue_database" {
  value = aws_glue_catalog_database.slabble.name
}

output "glue_table" {
  value = aws_glue_catalog_table.events.name
}
