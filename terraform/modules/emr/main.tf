###############################################################################
# KEY PAIR - SSH
###############################################################################

resource "tls_private_key" "emr" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "emr" {
  key_name   = var.key_name
  public_key = tls_private_key.emr.public_key_openssh
}

resource "local_file" "emr_pem" {
  content         = tls_private_key.emr.private_key_pem
  filename        = "${path.module}/../../keyPair/${var.key_name}.pem"
  file_permission = "0400"
}

###############################################################################
# IAM ROLE - EMR SERVICE
###############################################################################

resource "aws_iam_role" "emr_service" {
  name = "luana-lab-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "luana-lab-emr-service-role"
    Servico = "EMR"
  }
}

resource "aws_iam_role_policy_attachment" "emr_service_ec2" {
  role       = aws_iam_role.emr_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role_policy" "emr_service_logs" {
  name = "luana-lab-emr-service-logs-policy"
  role = aws_iam_role.emr_service.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_spark_arn,
          "${var.bucket_spark_arn}/*"
        ]
      }
    ]
  })
}

###############################################################################
# IAM ROLE - EC2 (INSTANCE PROFILE)
###############################################################################

resource "aws_iam_role" "emr_ec2" {
  name = "luana-lab-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "luana-lab-emr-ec2-role"
    Servico = "EMR"
  }
}

resource "aws_iam_instance_profile" "emr_ec2" {
  name = "luana-lab-emr-ec2-profile"
  role = aws_iam_role.emr_ec2.name
}

resource "aws_iam_role_policy" "emr_ec2_s3" {
  name = "luana-lab-emr-s3-policy"
  role = aws_iam_role.emr_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_landing_arn,
          "${var.bucket_landing_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_bronze_arn,
          "${var.bucket_bronze_arn}/*",
          var.bucket_spark_arn,
          "${var.bucket_spark_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "emr_ec2_glue" {
  name = "luana-lab-emr-glue-policy"
  role = aws_iam_role.emr_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:BatchCreatePartition"
        ]
        Resource = ["*"]
      }
    ]
  })
}

###############################################################################
# SECURITY GROUP - EMR
###############################################################################

resource "aws_security_group" "emr_master" {
  name        = "luana-lab-emr-master-sg"
  description = "Security Group do EMR Master"
  vpc_id      = var.vpc_id

  tags = {
    Name                                  = "luana-lab-emr-master-sg"
    Servico                               = "EMR"
    "for-use-with-amazon-emr-managed-policies" = "true"
  }
}

resource "aws_vpc_security_group_egress_rule" "emr_master_all" {
  security_group_id = aws_security_group.emr_master.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Permitir trafego de saida do EMR"
}

resource "aws_vpc_security_group_ingress_rule" "emr_master_ssh" {
  security_group_id = aws_security_group.emr_master.id

  cidr_ipv4   = "${var.ip_acesso}/32"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "Permitir SSH do IP do administrador"
}

resource "aws_security_group" "emr_core" {
  name        = "luana-lab-emr-core-sg"
  description = "Security Group do EMR Core"
  vpc_id      = var.vpc_id

  tags = {
    Name                                  = "luana-lab-emr-core-sg"
    Servico                               = "EMR"
    "for-use-with-amazon-emr-managed-policies" = "true"
  }
}

resource "aws_vpc_security_group_egress_rule" "emr_core_all" {
  security_group_id = aws_security_group.emr_core.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Permitir trafego de saida do EMR Core"
}

resource "aws_vpc_security_group_ingress_rule" "master_from_master" {
  security_group_id = aws_security_group.emr_master.id

  referenced_security_group_id = aws_security_group.emr_master.id
  ip_protocol                  = "-1"

  description = "Permitir trafego entre masters"
}

resource "aws_vpc_security_group_ingress_rule" "master_from_core" {
  security_group_id = aws_security_group.emr_master.id

  referenced_security_group_id = aws_security_group.emr_core.id
  ip_protocol                  = "-1"

  description = "Permitir trafego do Core para o Master"
}

resource "aws_vpc_security_group_ingress_rule" "core_from_core" {
  security_group_id = aws_security_group.emr_core.id

  referenced_security_group_id = aws_security_group.emr_core.id
  ip_protocol                  = "-1"

  description = "Permitir trafego entre cores"
}

resource "aws_vpc_security_group_ingress_rule" "core_from_master" {
  security_group_id = aws_security_group.emr_core.id

  referenced_security_group_id = aws_security_group.emr_master.id
  ip_protocol                  = "-1"

  description = "Permitir trafego do Master para o Core"
}

###############################################################################
# EMR CLUSTER
###############################################################################

resource "aws_emr_cluster" "spark" {
  name          = "luana-lab-emr-spark"
  release_label = "emr-7.0.0"
  applications  = ["Spark"]

  service_role = aws_iam_role.emr_service.arn

  log_uri = "s3://${var.bucket_spark_nome}/emr-logs/"

  ec2_attributes {
    instance_profile                  = aws_iam_instance_profile.emr_ec2.arn
    subnet_id                         = var.subnet_id
    key_name                          = aws_key_pair.emr.key_name
    emr_managed_master_security_group = aws_security_group.emr_master.id
    emr_managed_slave_security_group  = aws_security_group.emr_core.id
  }

  master_instance_group {
    instance_type  = "m4.large"
    instance_count = 1
  }

  core_instance_group {
    instance_type  = "m4.large"
    instance_count = 1
  }

  auto_termination_policy {
    idle_timeout = 900
  }

  configurations_json = jsonencode([
    {
      Classification = "iceberg-defaults"
      Properties = {
        "iceberg.enabled" = "true"
      }
    },
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.sql.catalog.glue_catalog"              = "org.apache.iceberg.spark.SparkCatalog"
        "spark.sql.catalog.glue_catalog.catalog-impl" = "org.apache.iceberg.aws.glue.GlueCatalog"
        "spark.sql.catalog.glue_catalog.warehouse"    = "s3://${var.bucket_bronze_nome}/"
        "spark.sql.catalog.glue_catalog.io-impl"      = "org.apache.iceberg.aws.s3.S3FileIO"
        "spark.sql.extensions"                        = "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions"
      }
    }
  ])

  keep_job_flow_alive_when_no_steps = true

  tags = {
    Name    = "luana-lab-emr-spark"
    Servico = "EMR"
  }
}
