output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.principal.id
}

output "subnets_publicas_ids" {
  description = "IDs das subnets públicas"
  value = {
    publica_a = aws_subnet.subnet["publica_a"].id
    publica_b = aws_subnet.subnet["publica_b"].id
  }
}

output "subnets_privadas_ids" {
  description = "IDs das subnets privadas"
  value = {
    privada_a = aws_subnet.subnet["privada_a"].id
    privada_b = aws_subnet.subnet["privada_b"].id
  }
}