output "cluster_id" {
  description = "ID do cluster EMR"

  value = aws_emr_cluster.spark.id
}

output "master_public_dns" {
  description = "DNS publico do master node"

  value = aws_emr_cluster.spark.master_public_dns
}

output "pem_file_path" {
  description = "Caminho do arquivo .pem gerado"

  value = local_file.emr_pem.filename
}
