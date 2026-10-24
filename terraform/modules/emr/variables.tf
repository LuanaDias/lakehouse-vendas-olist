variable "bucket_landing_arn" {
  description = "ARN do bucket S3 da camada landing"
  type        = string
}

variable "bucket_bronze_arn" {
  description = "ARN do bucket S3 da camada bronze"
  type        = string
}

variable "bucket_bronze_nome" {
  description = "Nome do bucket S3 da camada bronze"
  type        = string
}

variable "bucket_spark_arn" {
  description = "ARN do bucket S3 do Spark"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet para o EMR"
  type        = string
}

variable "bucket_spark_nome" {
  description = "Nome do bucket S3 do Spark (para logs)"
  type        = string
}

variable "key_name" {
  description = "Nome da key pair EC2 para SSH no EMR"
  type        = string
}

variable "ip_acesso" {
  description = "IP publico para acesso SSH ao master (formato x.x.x.x/32)"
  type        = string
}
