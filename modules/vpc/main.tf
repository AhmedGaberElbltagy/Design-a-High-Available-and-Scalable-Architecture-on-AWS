resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name        = "${var.vpc_name}"
    Type        = "VPC"
    Description = "Main VPC for production web application"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name        = "${var.vpc_name}-internet-gateway"
    Type        = "InternetGateway"
    Description = "Internet Gateway for ALB public access"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name             = "${var.vpc_name}-public-subnet-${var.availability_zones[count.index]}"
    Type             = "PublicSubnet"
    Tier             = "public"
    AvailabilityZone = var.availability_zones[count.index]
    Description      = "Public subnet for ALB in ${var.availability_zones[count.index]}"
  })
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-gateway-eip"
    Type = "ElasticIP"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-gateway"
    Type = "NATGateway"
  })

  depends_on = [aws_internet_gateway.main]
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name             = "${var.vpc_name}-private-subnet-${var.availability_zones[count.index]}"
    Type             = "PrivateSubnet"
    Tier             = "private"
    AvailabilityZone = var.availability_zones[count.index]
    Description      = "Private subnet for EC2 instances in ${var.availability_zones[count.index]}"
  })
}

# Database Subnets
# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name        = "${var.vpc_name}-public-route-table"
    Type        = "RouteTable"
    Tier        = "public"
    Description = "Route table for public subnets with internet access"
  })
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name        = "${var.vpc_name}-private-route-table"
    Type        = "RouteTable"
    Tier        = "private"
    Description = "Route table for private subnets with NAT gateway access"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}