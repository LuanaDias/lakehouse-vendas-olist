resource "aws_db_parameter_group" "postgresql" {
  name   = "${var.nome_instancia}-parametros"
  family = "postgres16"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "${var.nome_instancia}-parametros"
  }
}

resource "aws_security_group" "postgresql" {
  name        = "${var.nome_instancia}-sg"
  description = "Security Group exclusivo do PostgreSQL RDS"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "${var.nome_instancia}-sg"
    Servico = "PostgreSQL"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgresql_ip" {
  security_group_id = aws_security_group.postgresql.id

  cidr_ipv4   = "${var.ip_acesso}/32"
  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"

  description = "Acesso temporario ao PostgreSQL a partir do IP autorizado"
}

resource "aws_db_subnet_group" "postgresql" {
  name = "${var.nome_instancia}-subnet-group"

  subnet_ids = var.subnets_ids

  tags = {
    Name = "${var.nome_instancia}-subnet-group"
  }
}

resource "aws_db_instance" "postgresql" {
  identifier = var.nome_instancia

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.nome_banco
  username = var.usuario

  manage_master_user_password = true

  parameter_group_name   = aws_db_parameter_group.postgresql.name
  db_subnet_group_name   = aws_db_subnet_group.postgresql.name
  vpc_security_group_ids = [aws_security_group.postgresql.id]

  publicly_accessible = true

  backup_retention_period = 1

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name    = var.nome_instancia
    Servico = "PostgreSQL"
  }
}