output "rule_arn" {
  description = "ARN da regra EventBridge"

  value = aws_cloudwatch_event_rule.gerar_pedidos.arn
}
