variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "subnets_privadas_ids" {
  description = "IDs das subnets privadas onde a Lambda será executada"
  type        = list(string)
}

variable "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL"
  type        = string
}

variable "rds_porta" {
  description = "Porta do RDS PostgreSQL"
  type        = number
}

variable "rds_nome_banco" {
  description = "Nome do banco de dados"
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
