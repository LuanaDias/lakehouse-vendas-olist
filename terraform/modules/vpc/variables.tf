variable "nome_vpc" {
  description = "Nome da VPC"
  type        = string
}

variable "cidr_vpc" {
  description = "Bloco CIDR da VPC"
  type        = string
}

variable "azs" {
  description = "Zonas de disponibilidade utilizadas"
  type        = list(string)
}