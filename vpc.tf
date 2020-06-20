provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

resource "tls_private_key" "elasticsearch_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "elasticsearch_key" {
  key_name   = "elasticsearch_key"
  public_key = tls_private_key.elasticsearch_key.public_key_openssh
}

resource "local_file" "local_ssh_private_key" {
  content         = tls_private_key.elasticsearch_key.private_key_pem
  filename        = "ssh-key-private.pem"
  file_permission = "0400"
}

# create the VPC
resource "aws_vpc" "Elasticsearch_VPC" {
  cidr_block           = var.vpcCIDRblock
  instance_tenancy     = var.instanceTenancy
  enable_dns_support   = var.dnsSupport
  enable_dns_hostnames = var.dnsHostNames

  tags = {
    Name = "Elasticsearch VPC"
  }

} # end resource

# create the Subnet
resource "aws_subnet" "Elasticsearch_Subnet" {
  vpc_id                  = aws_vpc.Elasticsearch_VPC.id
  cidr_block              = var.subnetCIDRblock
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone

  tags = {
    Name = "Elasticsearch Subnet"
  }
} # end resource


# Create Security Group
resource "aws_security_group" "elasticsearch-sg" {
  name = "elasticsearch-sg"

  # Inbound for port 9200
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # I am opening port 22 from public internet (0.0.0.0/0), because currently i don't have vpn or bastion host.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # To Allow traffic from Any IP
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create VPC Network access control list
resource "aws_network_acl" "My_Elasticsearch_Security_ACL" {
  vpc_id     = aws_vpc.Elasticsearch_VPC.id
  subnet_ids = ["${aws_subnet.Elasticsearch_Subnet.id}"]

  # allow ingress port 22
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 22
    to_port    = 22
  }

  # allow ingress port 9200 
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 9200
    to_port    = 9200
  }

  # allow ingress ephemeral ports 
  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 1024
    to_port    = 65535
  }

  # allow egress port 22 
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 22
    to_port    = 22
  }

  # allow egress port 9200 
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 9200
    to_port    = 9200
  }

  # allow egress ephemeral ports
  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 1024
    to_port    = 65535
  }
  tags = {
    Name = "Elasticsearch ACL"
  }
} # end resource

# Create the Internet Gateway
resource "aws_internet_gateway" "Elasticsearch_VPC_GW" {
  vpc_id = aws_vpc.Elasticsearch_VPC.id
  tags = {
    Name = "Elasticsearch VPC Internet Gateway"
  }
} # end resource

# Create the Route Table
resource "aws_route_table" "Elasticsearch_VPC_route_table" {
  vpc_id = aws_vpc.Elasticsearch_VPC.id
  tags = {
    Name = "Elasticsearch VPC Route Table"
  }
} # end resource

# Create the Internet Access
resource "aws_route" "Elasticsearch_VPC_internet_access" {
  route_table_id         = aws_route_table.Elasticsearch_VPC_route_table.id
  destination_cidr_block = var.destinationCIDRblock
  gateway_id             = aws_internet_gateway.Elasticsearch_VPC_GW.id
} # end resource

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "Elasticsearch_VPC_association" {
  subnet_id      = aws_subnet.Elasticsearch_Subnet.id
  route_table_id = aws_route_table.Elasticsearch_VPC_route_table.id
} # end resource

# Create EC2 instance
resource "aws_instance" "elasticsearch_instance" {
  ami                    = "${var.instance_ami}"
  instance_type          = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.elasticsearch-sg.id}"]
  key_name               = aws_key_pair.elasticsearch_key.key_name
  subnet_id              = aws_subnet.Elasticsearch_Subnet.id
  # Copy bash script into new EC2 instance which will configure elasticsearch
  provisioner "file" {
    source      = "els.sh"
    destination = "/tmp/els.sh"
  } # Change permissions on bash script and execute from ec2-user.
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/els.sh",
      "sudo sh /tmp/els.sh",
    ]
  }

  # Login to the ec2-user with the aws key.
  connection {
    type        = "ssh"
    user        = "${var.users}"
    private_key = tls_private_key.elasticsearch_key.private_key_pem
    host        = self.public_ip
  }

  tags = {
    Name = "Elasticsearch-Server"
  }
}

output "public_ip" {
  value = "${aws_instance.elasticsearch_instance.public_ip}"
}
