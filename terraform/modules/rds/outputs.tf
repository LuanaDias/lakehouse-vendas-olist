output "endpoint" {
  description = "Endpoint do RDS PostgreSQL"
  value       = aws_db_instance.postgresql.address
}

output "porta" {
  description = "Porta do PostgreSQL"
  value       = aws_db_instance.postgresql.port
}

output "nome_banco" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.postgresql.db_name
}

output "security_group_id" {
  description = "ID do Security Group do PostgreSQL"
  value       = aws_security_group.postgresql.id
}

output "secret_arn" {
  description = "ARN do secret com as credenciais do RDS"
  value       = aws_db_instance.postgresql.master_user_secret[0].secret_arn
}