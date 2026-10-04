output "nomes_buckets" {
  description = "Nomes dos buckets do Data Lake"
  value = {
    for camada, bucket in aws_s3_bucket.data_lake :
    camada => bucket.bucket
  }
}