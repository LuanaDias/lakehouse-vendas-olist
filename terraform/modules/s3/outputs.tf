output "nomes_buckets" {
  description = "Nomes dos buckets do Data Lake"

  value = {
    for camada, bucket in aws_s3_bucket.data_lake :
    camada => bucket.bucket
  }
}

output "arn_bronze" {
  description = "ARN do bucket Bronze"

  value = aws_s3_bucket.data_lake["bronze"].arn
}

output "arn_landing" {
  description = "ARN do bucket Landing"

  value = aws_s3_bucket.data_lake["landing"].arn
}

output "nome_landing" {
  description = "Nome do bucket Landing"

  value = aws_s3_bucket.data_lake["landing"].bucket
}

output "nome_bronze" {
  description = "Nome do bucket Bronze"

  value = aws_s3_bucket.data_lake["bronze"].bucket
}

output "nome_spark" {
  description = "Nome do bucket Spark"

  value = aws_s3_bucket.data_lake["spark"].bucket
}

output "arn_spark" {
  description = "ARN do bucket Spark"

  value = aws_s3_bucket.data_lake["spark"].arn
}
