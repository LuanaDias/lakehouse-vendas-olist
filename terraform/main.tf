module "budget" {
  source = "./modules/budget"

  budget_name  = "luana-lab-budget"
  limit_amount = 1
  alert_email  = "luana.dias@stacktecnologias.com.br"
}

module "s3" {
  source = "./modules/s3"

  bucket_prefix = "luana-lab-data-lake"
}