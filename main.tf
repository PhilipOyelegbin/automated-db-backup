# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Fetch available availability zones for your region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create subnets dynamically
resource "aws_subnet" "pub-subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-pub-subnet-${count.index + 1}"
  }

  depends_on = [aws_vpc.main]
}

resource "aws_subnet" "priv-subnet" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs[count.index + 2]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.project_name}-priv-subnet-${count.index + 1}"
  }

  depends_on = [aws_vpc.main]
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create a NAT Gateway EIP
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# Creating a NAT gateway in the first PUBLIC subnet
resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.pub-subnet[0].id
  allocation_id = aws_eip.nat_eip.id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_eip.nat_eip]
}

# Create a Public Route Table
resource "aws_route_table" "pub-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-pub-rt"
  }
}

# Associating public subnets with the public route table
resource "aws_route_table_association" "sa-pub-rt-assoc" {
  count          = 2
  subnet_id      = aws_subnet.pub-subnet[count.index].id
  route_table_id = aws_route_table.pub-rt.id
}

# Creating a private route table
resource "aws_route_table" "priv-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-priv-rt"
  }
}

# Associating private subnets with the private route table
resource "aws_route_table_association" "priv-rt-assoc" {
  count          = 2
  subnet_id      = aws_subnet.priv-subnet[count.index].id
  route_table_id = aws_route_table.priv-rt.id
}

module "local_ec2" {
  source       = "./ec2"
  project_name = var.project_name
  keypair_name = "ops-key"
  instance_image = {
    owners = ["137112412989", "136693071363"]
    values = ["al2023-ami-2023.9.20251110.1-kernel-6.1-x86_64", "debian-13-amd64-20251006-2257"]
  }
  instance_type = "t3.micro"
  vpc_id        = aws_vpc.main.id
  subnets_id = {
    public_subnets  = aws_subnet.pub-subnet[*].id
    private_subnets = aws_subnet.priv-subnet[*].id
  }
  subnets_cidr = {
    public_subnets  = aws_subnet.pub-subnet[*].cidr_block
    private_subnets = aws_subnet.priv-subnet[*].cidr_block
  }
}