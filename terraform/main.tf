###############################################################################
#########              IP AUTOMATICO                            ###############
###############################################################################

data "http" "meu_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  ip_acesso = trimspace(data.http.meu_ip.response_body)
}

###############################################################################
#########              DATA SOURCES - S3 criados manualmente    ###############
###############################################################################

data "aws_s3_bucket" "landing" {
  bucket = "luana-lab-data-lake-landing"
}

data "aws_s3_bucket" "bronze" {
  bucket = "luana-lab-data-lake-bronze"
}

resource "aws_s3_bucket" "spark" {
  bucket        = "luana-lab-data-lake-spark"
  force_destroy = true

  tags = {
    Nome   = "luana-lab-data-lake-spark"
    Camada = "spark"
  }
}

###############################################################################
#########              BUDGET - ALERTA DE CUSTO                 ###############
###############################################################################

module "budget" {
  source = "./modules/budget"

  budget_name  = "luana-lab-budget"
  limit_amount = 1
  alert_email  = var.alert_email
}

###############################################################################
#########              S3 - DATA LAKE                          ###############
#########              Landing | Bronze | Silver | Gold         ###############
###############################################################################

#module "s3" {
#  source = "./modules/s3"

#  bucket_prefix = "luana-lab-data-lake"
#}

###############################################################################
#########             VPC E SUBNETS                               #############
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  nome_vpc = "luana-lab-vpc"
  cidr_vpc = "10.0.0.0/16"

  azs = [
    "us-east-1a",
    "us-east-1b"
  ]
}

###############################################################################
#########              RDS - POSTGRESQL                        ###############
###############################################################################


module "rds" {
  source = "./modules/rds"

  nome_instancia = "luana-lab-postgresql"
  nome_banco     = "olist"
  usuario        = "dbadmin"

  vpc_id = module.vpc.vpc_id

  subnets_ids = values(module.vpc.subnets_publicas_ids)

  ip_acesso = local.ip_acesso
}


###############################################################################
#########              DMS                                      ###############
###############################################################################

module "dms" {
  source = "./modules/dms"

  #bucket_landing_arn  = module.s3.arn_landing
  bucket_landing_arn  = data.aws_s3_bucket.landing.arn
  #bucket_landing_nome = module.s3.nome_landing
  bucket_landing_nome = data.aws_s3_bucket.landing.id

  vpc_id               = module.vpc.vpc_id
  subnets_privadas_ids = values(module.vpc.subnets_privadas_ids)

  rds_endpoint          = module.rds.endpoint
  rds_porta             = module.rds.porta
  rds_nome_banco        = module.rds.nome_banco
  rds_secret_arn        = module.rds.secret_arn
  rds_security_group_id = module.rds.security_group_id
}

###############################################################################
#########              LAMBDA - GERAR PEDIDOS                   ###############
###############################################################################

module "lambda" {
  source = "./modules/lambda"

  vpc_id               = module.vpc.vpc_id
  subnets_privadas_ids = values(module.vpc.subnets_privadas_ids)

  rds_endpoint          = module.rds.endpoint
  rds_porta             = module.rds.porta
  rds_nome_banco        = module.rds.nome_banco
  rds_secret_arn        = module.rds.secret_arn
  rds_security_group_id = module.rds.security_group_id
}

###############################################################################
#########              EVENTBRIDGE - AGENDAMENTO                ###############
###############################################################################

module "eventbridge" {
  source = "./modules/eventbridge"

  lambda_arn           = module.lambda.lambda_arn
  lambda_function_name = module.lambda.lambda_function_name
}

###############################################################################
#########              GLUE CATALOG                             ###############
###############################################################################

module "glue" {
  source = "./modules/glue"

  #bucket_bronze_nome = module.s3.nome_bronze
  bucket_bronze_nome = data.aws_s3_bucket.bronze.id
}

###############################################################################
#########              EMR - SPARK (EC2)                        ###############
###############################################################################

module "emr" {
  source = "./modules/emr"

  #bucket_landing_arn = module.s3.arn_landing
  bucket_landing_arn = data.aws_s3_bucket.landing.arn
  #bucket_bronze_arn  = module.s3.arn_bronze
  bucket_bronze_arn  = data.aws_s3_bucket.bronze.arn
  #bucket_bronze_nome = module.s3.nome_bronze
  bucket_bronze_nome = data.aws_s3_bucket.bronze.id
  #bucket_spark_arn   = module.s3.arn_spark
  bucket_spark_arn   = aws_s3_bucket.spark.arn
  #bucket_spark_nome  = module.s3.nome_spark
  bucket_spark_nome  = aws_s3_bucket.spark.id

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.subnets_publicas_ids["publica_a"]

  key_name  = var.emr_key_name
  ip_acesso = local.ip_acesso
}
