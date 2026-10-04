module "budget" {
  source = "./modules/budget"

  budget_name  = "luana-lab-budget"
  limit_amount = 1
  alert_email  = "luana.dias@stacktecnologias.com.br"
}