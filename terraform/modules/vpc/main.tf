resource "aws_vpc" "principal" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.nome_vpc
  }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${var.nome_vpc}-igw"
  }
}

locals {
  subnets = {
    publica_a = {
      cidr = "10.0.1.0/24"
      az   = var.azs[0]
      tipo = "publica"
    }

    publica_b = {
      cidr = "10.0.2.0/24"
      az   = var.azs[1]
      tipo = "publica"
    }

    privada_a = {
      cidr = "10.0.11.0/24"
      az   = var.azs[0]
      tipo = "privada"
    }

    privada_b = {
      cidr = "10.0.12.0/24"
      az   = var.azs[1]
      tipo = "privada"
    }
  }
}

resource "aws_subnet" "subnet" {
  for_each = local.subnets

  vpc_id            = aws_vpc.principal.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.tipo == "publica"

  tags = {
    Name = "${var.nome_vpc}-${each.key}"
    Tipo = each.value.tipo
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = {
    Name = "${var.nome_vpc}-rt-publica"
  }
}

resource "aws_route_table_association" "publica" {
  for_each = {
    publica_a = aws_subnet.subnet["publica_a"].id
    publica_b = aws_subnet.subnet["publica_b"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${var.nome_vpc}-rt-privada"
  }
}

resource "aws_route_table_association" "privada" {
  for_each = {
    privada_a = aws_subnet.subnet["privada_a"].id
    privada_b = aws_subnet.subnet["privada_b"].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.privada.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.principal.id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    aws_route_table.publica.id,
    aws_route_table.privada.id,
  ]

  tags = {
    Name = "${var.nome_vpc}-vpce-s3"
  }
}