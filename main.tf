terraform {
  required_providers {
    aws = {
  }
}
}

#connect to AWS account

variable "access_key" {
  description = "Access key for AWS console"

}

variable "secret_key" {
  description = "Secret key for AWS console"

}

provider "aws" {
      region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
    
  }
 
# Create a VPC

resource "aws_vpc" "my-first-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "production"
  }
}

#create internet gateway for webserver

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-first-vpc.id

  tags = {
    Name = "internet_gateway"
  }
}

#create a route table to give default route to GW

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.my-first-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  

  tags = {
    Name = "prod"
  }
}

#create a subnet

variable "subnet_prefix" {
  description = "cidr block for the subnet"

}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.my-first-vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "us-east-1b"
  tags = {
    Name = "prod-subnet"
  }
}

#associate route table with subnet

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#create a security group for the web server to be access via HTTP, HTTPS, or SSH

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.my-first-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    #any protocol 
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


#network interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#assign an elatic ip to the network interface

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

#automatically print out elastic ip without having to go to the aws console
output "server_public_ip" {
  value = aws_eip.one.public_ip
}

#create ubuntu server and install//enable appache

resource "aws_instance" "my-first-server" {
  ami           = "ami-0747bdcabd34c712a"
  instance_type = "t2.micro"
  availability_zone = "us-east-1b"
  #reference key pair for ssh to instance
  key_name = "main-key"
  
  network_interface {
    device_index= 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  tags = {
    Name = "Web-Server"
  }

  user_data = <<-EOF
   #!/bin/bash
   sudo apt update -y
   sudo apt install apache2 -y
   sudo sytemctl start apache2
   sudo bash -c 'echo Hi This is my project! > /var/www/html/index.html'
   EOF
}

output "server_private_ip" {
  value = aws_instance.my-first-server.private_ip
}

output "server_id" {
  value = aws_instance.my-first-server.id
}



