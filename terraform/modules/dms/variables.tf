variable "bucket_landing_arn" {
  description = "ARN do bucket Landing utilizado como destino pelo DMS"
  type        = string
}

variable "bucket_landing_nome" {
  description = "Nome do bucket Landing"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o DMS será criado"
  type        = string
}

variable "subnets_privadas_ids" {
  description = "IDs das subnets privadas utilizadas pelo DMS"
  type        = list(string)
}

variable "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL (origem)"
  type        = string
}

variable "rds_porta" {
  description = "Porta do RDS PostgreSQL"
  type        = number
}

variable "rds_nome_banco" {
  description = "Nome do banco de dados no RDS"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN do secret com credenciais do RDS"
  type        = string
}

variable "rds_security_group_id" {
  description = "ID do Security Group do RDS"
  type        = string
}
