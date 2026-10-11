variable "nome_instancia" {
  description = "Nome da instancia RDS PostgreSQL"
  type        = string
}

variable "nome_banco" {
  description = "Nome do banco de dados Olist"
  type        = string
}

variable "usuario" {
  description = "Usuario administrador do PostgreSQL"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o RDS sera criado"
  type        = string
}

variable "subnets_ids" {
  description = "IDs das subnets utilizadas pelo RDS"
  type        = list(string)
}

variable "ip_acesso" {
  description = "IP publico autorizado a acessar o PostgreSQL"
  type        = string
}