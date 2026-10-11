resource "aws_dms_replication_subnet_group" "dms" {
  replication_subnet_group_id          = "luana-lab-dms-subnet-group"
  replication_subnet_group_description = "Subnets privadas utilizadas pelo AWS DMS"

  subnet_ids = var.subnets_privadas_ids

  tags = {
    Name    = "luana-lab-dms-subnet-group"
    Servico = "DMS"
  }
}