output "lambda_arn" {
  description = "ARN da Lambda de geracao de pedidos"

  value = aws_lambda_function.gerar_pedidos.arn
}

output "lambda_function_name" {
  description = "Nome da Lambda de geracao de pedidos"

  value = aws_lambda_function.gerar_pedidos.function_name
}
