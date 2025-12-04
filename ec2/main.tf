data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

#============================================ Security Groups ============================================#
resource "aws_security_group" "bastion-sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH and Monitoring inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Zabbix access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32", var.subnets_cidr.public_subnets[0], var.subnets_cidr.public_subnets[1]]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_security_group" "web-sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Panel access"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

resource "aws_security_group" "database-sg" {
  name        = "${var.project_name}-database-sg"
  description = "Allow custom inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL access"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
  }

  ingress {
    description     = "MongoDB access"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    # security_groups = [aws_security_group.web-sg.id]
  }

  ingress {
    description     = "SSH access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-database-sg"
  }
}

#============================================ Server Instance ============================================#
# Define the AMI data source to fetch the latest Ubuntu AMI
data "aws_ami" "image1" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.instance_image.values[0]]
  }

  owners = [var.instance_image.owners[0]]
}

data "aws_ami" "image2" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.instance_image.values[1]]
  }

  owners = [var.instance_image.owners[1]]
}

# Define SSH keypair
resource "aws_key_pair" "admin-key" {
  key_name   = "${var.project_name}-${var.keypair_name}"
  public_key = file("${path.root}/id_rsa.pub")
}

# Creating an EC2 instance as a bastion host
resource "aws_instance" "bastion-server" {
  ami                         = data.aws_ami.image1.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnets_id.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  key_name                    = aws_key_pair.admin-key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-bastion-server"
  }
}

# Creating EC2 instances as app servers
resource "aws_instance" "app-servers" {
  ami                         = data.aws_ami.image2.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnets_id.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.web-sg.id, aws_security_group.database-sg.id]
  key_name                    = aws_key_pair.admin-key.key_name
  associate_public_ip_address = true

  user_data = file("${path.root}/userdata/app-server.sh")

  tags = {
    Name = "${var.project_name}-app-server"
  }
}

