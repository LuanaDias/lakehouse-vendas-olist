###############################################################################
# GLUE CATALOG DATABASE - BRONZE
###############################################################################

resource "aws_glue_catalog_database" "bronze" {
  name = "luana_lab_bronze"

  location_uri = "s3://${var.bucket_bronze_nome}/bronze/"

  tags = {
    Name    = "luana-lab-glue-bronze"
    Servico = "Glue"
    Camada  = "bronze"
  }
}
