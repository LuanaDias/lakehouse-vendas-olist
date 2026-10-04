# Bucket de state foi criado manualmente 

#aws s3api create-bucket `
#  --bucket luana-lab-terraform-state `
#  --region us-east-1 `
#  --object-ownership BucketOwnerEnforced `
#  --profile lab

locals {
  camadas = toset([
    "landing",
    "bronze",
    "silver",
    "gold"
  ])
}

# Criação dos buckets
resource "aws_s3_bucket" "data_lake" {
  for_each = local.camadas

  bucket = "${var.bucket_prefix}-${each.key}"

  tags = {
    Nome   = "${var.bucket_prefix}-${each.key}"
    Camada = each.key
  }
}

# Versionamento dos buckets
resource "aws_s3_bucket_versioning" "data_lake" {
  for_each = local.camadas

  bucket = aws_s3_bucket.data_lake[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia dos buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  for_each = local.camadas

  bucket = aws_s3_bucket.data_lake[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueio de acesso público
resource "aws_s3_bucket_public_access_block" "data_lake" {
  for_each = local.camadas

  bucket = aws_s3_bucket.data_lake[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle da camada landing
resource "aws_s3_bucket_lifecycle_configuration" "landing" {
  bucket = aws_s3_bucket.data_lake["landing"].id

  rule {
    id     = "landing-lifecycle"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}