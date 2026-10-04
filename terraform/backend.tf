terraform {
  backend "s3" {
    bucket       = "luana-lab-terraform-state"
    key          = "terraform/lakehouse-vendas-olist/terraform.tfstate"
    region       = "us-east-1"
    profile      = "lab"
    use_lockfile = true
  }
}

# terraform init -migrate-state