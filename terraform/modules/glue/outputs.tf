output "database_bronze_name" {
  description = "Nome do database bronze no Glue Catalog"

  value = aws_glue_catalog_database.bronze.name
}
