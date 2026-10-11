###############################################################################
# REGRA DE AGENDAMENTO - A CADA 5 MINUTOS
###############################################################################

resource "aws_cloudwatch_event_rule" "gerar_pedidos" {
  name                = "luana-lab-gerar-pedidos"
  description         = "Dispara Lambda de geracao de pedidos a cada 5 minutos"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name    = "luana-lab-gerar-pedidos"
    Servico = "EventBridge"
  }
}

###############################################################################
# TARGET - LAMBDA
###############################################################################

resource "aws_cloudwatch_event_target" "gerar_pedidos" {
  rule = aws_cloudwatch_event_rule.gerar_pedidos.name
  arn  = var.lambda_arn
}

###############################################################################
# PERMISSÃO PARA EVENTBRIDGE INVOCAR A LAMBDA
###############################################################################

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.gerar_pedidos.arn
}
