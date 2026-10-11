###############################################################################
# IAM ROLE - DMS -> S3
###############################################################################

resource "aws_iam_role" "dms_s3" {
  name = "luana-lab-dms-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "dms.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "luana-lab-dms-s3-role"
    Servico = "DMS"
  }
}

resource "aws_iam_role_policy" "dms_s3" {
  name = "luana-lab-dms-s3-policy"
  role = aws_iam_role.dms_s3.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = var.bucket_landing_arn
      },
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectTagging"
        ]

        Resource = "${var.bucket_landing_arn}/*"
      }
    ]
  })
}

###############################################################################
# SECURITY GROUP
###############################################################################

resource "aws_security_group" "dms" {
  name        = "luana-lab-dms-sg"
  description = "Security Group da AWS DMS"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "luana-lab-dms-sg"
    Servico = "DMS"
  }
}

resource "aws_vpc_security_group_egress_rule" "dms_all" {
  security_group_id = aws_security_group.dms.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Permitir trafego de saida do DMS"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_dms" {
  security_group_id = var.rds_security_group_id

  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = var.rds_porta
  to_port                      = var.rds_porta
  ip_protocol                  = "tcp"

  description = "Permitir acesso do DMS ao RDS"
}

###############################################################################
# SUBNET GROUP
###############################################################################

resource "aws_dms_replication_subnet_group" "dms" {
  replication_subnet_group_id          = "luana-lab-dms-subnet-group"
  replication_subnet_group_description = "Subnets privadas utilizadas pelo AWS DMS"

  subnet_ids = var.subnets_privadas_ids

  tags = {
    Name    = "luana-lab-dms-subnet-group"
    Servico = "DMS"
  }
}

###############################################################################
# REPLICATION INSTANCE
###############################################################################

resource "aws_dms_replication_instance" "dms" {
  replication_instance_id    = "luana-lab-dms"
  replication_instance_class = "dms.t3.small"
  allocated_storage          = 20

  vpc_security_group_ids = [aws_security_group.dms.id]
  replication_subnet_group_id = aws_dms_replication_subnet_group.dms.id

  publicly_accessible = false
  multi_az            = false

  tags = {
    Name    = "luana-lab-dms"
    Servico = "DMS"
  }
}

###############################################################################
# ENDPOINT ORIGEM - RDS POSTGRESQL
###############################################################################

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = var.rds_secret_arn
}

locals {
  rds_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)
}

resource "aws_dms_endpoint" "rds_origem" {
  endpoint_id   = "luana-lab-rds-origem"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = var.rds_endpoint
  port          = var.rds_porta
  database_name = var.rds_nome_banco
  username      = local.rds_credentials["username"]
  password      = local.rds_credentials["password"]
  ssl_mode      = "require"

  tags = {
    Name    = "luana-lab-rds-origem"
    Servico = "DMS"
  }
}

###############################################################################
# ENDPOINT DESTINO - S3 LANDING
###############################################################################

resource "aws_dms_s3_endpoint" "s3_landing" {
  endpoint_id   = "luana-lab-s3-landing-destino"
  endpoint_type = "target"

  bucket_name             = var.bucket_landing_nome
  service_access_role_arn = aws_iam_role.dms_s3.arn
  data_format             = "parquet"
  parquet_version         = "parquet-2-0"
  timestamp_column_name   = "dms_load_timestamp"

  tags = {
    Name    = "luana-lab-s3-landing"
    Servico = "DMS"
  }
}

###############################################################################
# REPLICATION TASK - FULL LOAD + CDC
###############################################################################

resource "aws_dms_replication_task" "rds_to_s3" {
  replication_task_id      = "luana-lab-rds-to-s3-landing"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.dms.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.rds_origem.endpoint_arn
  target_endpoint_arn      = aws_dms_s3_endpoint.s3_landing.endpoint_arn

  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "todas-tabelas-public"

        object-locator = {
          schema-name = "public"
          table-name  = "%"
        }

        rule-action = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema        = ""
      SupportLobs         = true
      FullLobMode         = false
      LobChunkSize        = 64
      LimitedSizeLobMode  = true
      LobMaxSize          = 32
    }

    FullLoadSettings = {
      TargetTablePrepMode = "DROP_AND_CREATE"
      MaxFullLoadSubTasks = 8
    }

    Logging = {
      EnableLogging = true
    }
  })

  start_replication_task = false

  tags = {
    Name    = "luana-lab-rds-to-s3-landing"
    Servico = "DMS"
  }
}

###############################################################################
# TESTAR CONEXÕES E INICIAR TASK AUTOMATICAMENTE
###############################################################################

resource "null_resource" "start_task" {
  depends_on = [aws_dms_replication_task.rds_to_s3]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = <<-EOT
      $repl = "${aws_dms_replication_instance.dms.replication_instance_arn}"
      $src  = "${aws_dms_endpoint.rds_origem.endpoint_arn}"
      $tgt  = "${aws_dms_s3_endpoint.s3_landing.endpoint_arn}"
      $task = "${aws_dms_replication_task.rds_to_s3.replication_task_arn}"

      Write-Host "Testando conexao com endpoint de origem..."
      aws dms test-connection --replication-instance-arn $repl --endpoint-arn $src --profile lab

      Write-Host "Testando conexao com endpoint de destino..."
      aws dms test-connection --replication-instance-arn $repl --endpoint-arn $tgt --profile lab

      Write-Host "Aguardando testes de conexao..."
      aws dms wait test-connection-succeeds --filters "Name=endpoint-arn,Values=$src" "Name=replication-instance-arn,Values=$repl" --profile lab
      aws dms wait test-connection-succeeds --filters "Name=endpoint-arn,Values=$tgt" "Name=replication-instance-arn,Values=$repl" --profile lab

      Write-Host "Iniciando replication task..."
      aws dms start-replication-task --replication-task-arn $task --start-replication-task-type start-replication --profile lab

      Write-Host "Task iniciada com sucesso!"
    EOT
  }
}
