###############################################################################
# IAM ROLE
###############################################################################

resource "aws_iam_role" "lambda" {
  name = "luana-lab-lambda-gerar-pedidos-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "luana-lab-lambda-gerar-pedidos-role"
    Servico = "Lambda"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "luana-lab-lambda-secrets-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.rds_secret_arn
      }
    ]
  })
}

###############################################################################
# SECURITY GROUP
###############################################################################

resource "aws_security_group" "lambda" {
  name        = "luana-lab-lambda-sg"
  description = "Security Group da Lambda de geracao de pedidos"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "luana-lab-lambda-sg"
    Servico = "Lambda"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_all" {
  security_group_id = aws_security_group.lambda.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Permitir trafego de saida da Lambda"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_lambda" {
  security_group_id = var.rds_security_group_id

  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = var.rds_porta
  to_port                      = var.rds_porta
  ip_protocol                  = "tcp"

  description = "Permitir acesso da Lambda ao RDS"
}

###############################################################################
# VPC ENDPOINT - SECRETS MANAGER
###############################################################################

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = var.subnets_privadas_ids
  security_group_ids = [aws_security_group.vpce_sm.id]

  tags = {
    Name    = "luana-lab-vpce-secretsmanager"
    Servico = "Lambda"
  }
}

resource "aws_security_group" "vpce_sm" {
  name        = "luana-lab-vpce-secretsmanager-sg"
  description = "Security Group do VPC Endpoint do Secrets Manager"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "luana-lab-vpce-secretsmanager-sg"
    Servico = "Lambda"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_sm_from_lambda" {
  security_group_id = aws_security_group.vpce_sm.id

  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"

  description = "Permitir acesso da Lambda ao Secrets Manager"
}

###############################################################################
# LAMBDA LAYER - PSYCOPG2
###############################################################################

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/psycopg2-layer.zip"
}

resource "aws_lambda_layer_version" "psycopg2" {
  filename            = data.archive_file.layer.output_path
  source_code_hash    = data.archive_file.layer.output_base64sha256
  layer_name          = "luana-lab-psycopg2"
  compatible_runtimes = ["python3.11"]
}

###############################################################################
# LAMBDA FUNCTION
###############################################################################

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda"
  output_path = "${path.module}/gerar_pedidos.zip"
}

resource "aws_lambda_function" "gerar_pedidos" {
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  function_name    = "luana-lab-gerar-pedidos"
  role             = aws_iam_role.lambda.arn
  handler          = "gerar_pedidos.handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  layers = [aws_lambda_layer_version.psycopg2.arn]

  vpc_config {
    subnet_ids         = var.subnets_privadas_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      RDS_ENDPOINT   = var.rds_endpoint
      RDS_PORT       = tostring(var.rds_porta)
      RDS_DATABASE   = var.rds_nome_banco
      RDS_SECRET_ARN = var.rds_secret_arn
    }
  }

  tags = {
    Name    = "luana-lab-gerar-pedidos"
    Servico = "Lambda"
  }
}

