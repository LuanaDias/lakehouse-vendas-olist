output "dms_s3_role_arn" {
  description = "ARN da IAM Role utilizada pelo DMS para acessar o S3"

  value = aws_iam_role.dms_s3.arn
}

output "replication_instance_arn" {
  description = "ARN da instancia de replicacao DMS"

  value = aws_dms_replication_instance.dms.replication_instance_arn
}

output "endpoint_origem_arn" {
  description = "ARN do endpoint de origem (RDS)"

  value = aws_dms_endpoint.rds_origem.endpoint_arn
}

output "endpoint_destino_arn" {
  description = "ARN do endpoint de destino (S3 Landing)"

  value = aws_dms_s3_endpoint.s3_landing.endpoint_arn
}
