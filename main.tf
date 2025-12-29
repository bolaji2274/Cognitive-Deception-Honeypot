# Advance  Honeypot Cognitve AI Infrastructure
provider "aws" {
  region = var.aws_region
  secret_key = var.aws_secret_key
  access_key = var.aws_access_key
}

#1. The isolated void "VPC" (no routes to production)
resource "aws_vpc" "deception_vpc" {
    # cidr_block = "172.31.0.0/16"
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    tags = {
        Name = "CDL-Deception-Network"
    }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.honeypot_vpc.id
  tags   = { Name = "Honeypot-IGW" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.honeypot_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "Honeypot-Public-Subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.honeypot_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
# 2. Security Groups: The lure
resource "aws_security_group" "trap_sg" {
  name = "trap-sg"
  vpc_id = aws_vpc.deception_vpc.id

  # open standard ports to the world 
  ingress {
    from_port = 22
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  # Allow the ai orchesration to pull logs, but allow NO outbound to internet
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "10.0.0.0/8" ] #internal only
  }
}

# --- IAM ROLE (For Systems Manager access if needed) ---
resource "aws_iam_role" "honeypot_role" {
  name = "honeypot_instance_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "honeypot_profile" {
  name = "honeypot_profile"
  role = aws_iam_role.honeypot_role.name
}
# 3. The "Labyrinth" Node (Ubuntu with AI-Agent)

resource "aws_instance" "labyrinth_node" {
  ami = data.aws_ami.ubuntu_24.id
  instance_type = "t3.medium"
  subnet_id = aws_subnet.public_subnet.id

  # Attach an IAM role that allows the node to talk ONLY to the AI Brain (Bedrock/OpenAI)
  iam_instance_profile =  aws_iam_instance_profile.honeypot_profile.name
  user_data = file("${path.module}/scripts/provision_cdl.sh")
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.trap_sg.id]

  tags = { Name = "CDL-Honeypot-Node" }
}

