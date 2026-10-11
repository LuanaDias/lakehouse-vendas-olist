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

module "s3" {
  source = "./modules/s3"

  bucket_prefix = "luana-lab-data-lake"
}

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

  ip_acesso = var.ip_acesso
}


###############################################################################
#########              DMS                                      ###############
###############################################################################

module "dms" {
  source = "./modules/dms"

  bucket_landing_arn  = module.s3.arn_landing
  bucket_landing_nome = module.s3.nome_landing

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