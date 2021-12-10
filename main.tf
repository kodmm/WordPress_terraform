# terraform {
#     required_providers {
#         aws = {
#             source = "hashicorp/aws"
#             version = "~>= 3.68.0"
#         }
#     }
# }
provider "aws" {
  region     = "ap-northeast-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "main" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"

  enable_dns_hostnames = "false"
  enable_dns_support   = "true"
  tags = {
    Name = "WordPress_vpc"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet#map_public_ip_on_launch
resource "aws_subnet" "public-a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "WP-PublicSubnet-1a"
  }
}

resource "aws_subnet" "private-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "WP-PrivateSubnet-1a"
  }
}

resource "aws_subnet" "private-d" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.10.0/24"
  availability_zone = "ap-northeast-1d"

  tags = {
    Name = "WP-PrivateSubnet-1d"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "WP-InternetGateway"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "public-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "vpc-public-table"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_main_route_table_association" "public-a" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.public-table.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "app" {
  name        = "WP-Web-DMZ"
  description = "WordPress Web App Security Group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "WP-Web-DMZ"
  }
}

resource "aws_security_group" "db" {
  name        = "WP-DB"
  description = "WordPress Mysql Security Group"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.app.id
}


resource "aws_security_group_rule" "mysql" {
  type      = "ingress"
  from_port = 3306
  to_port   = 3306
  protocol  = "tcp"

  source_security_group_id = aws_security_group.app.id

  security_group_id = aws_security_group.db.id
}

resource "aws_security_group_rule" "all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
resource "aws_db_subnet_group" "main" {
  name        = "wp-dbsubnet"
  description = "WordPress DB_Mysql_ Subnet"
  subnet_ids  = [aws_subnet.private-a.id, aws_subnet.private-d.id]

  tags = {
    Name = "WordPressDB"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
resource "aws_db_instance" "db" {
  identifier        = "wp-mysql-db" #lowcase
  allocated_storage = 5
  engine            = "mysql"
  engine_version    = "8.0.23"
  instance_class    = "db.t2.micro"

  storage_type            = "gp2"
  username                = var.username
  password                = var.password
  backup_retention_period = 0
  skip_final_snapshot = true
  apply_immediately = true
  vpc_security_group_ids  = [aws_security_group.db.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name

  lifecycle {
    ignore_changes = [password]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "test-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "app" {
  ami                         = var.ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public-a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app.id]

  private_ip = "10.1.1.100"

  key_name = aws_key_pair.deployer.id

  provisioner "file" {
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.public_ip
    }
    source = "prepareWordPress.sql"
    destination = "/home/ubuntu/prepareWordPress.sql"
  }

  
  
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.public_ip
    }
    scripts =[
      "init.sh",
      "nginx_config.sh",
    ]
  }
  
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.public_ip
    }
    inline = [
    "sudo apt update -y",
    "sudo apt install default-mysql-client -y",
    "sudo mysql -u ${var.username} -p${var.password} -h ${aws_db_instance.db.address} < /home/ubuntu/prepareWordPress.sql"
    ]
  }
  
  provisioner "file" {
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.public_ip
    }
    source = "nginx_default"
    destination = "/home/ubuntu/default"
  }
  
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host = self.public_ip
    }
    script = "wordpress_config.sh"
    
  }
  
  

  tags = {
    Name = "WordPressServer"
  }
}

output "WordPressServer_EC2__PublicIP" {
  value = aws_instance.app.public_ip
}

output "WordPressServer_EC2__PrivateIP" {
  value = aws_instance.app.private_ip
}

output "DBServer_mysql__address" {
  value = aws_db_instance.db.address
}

output "DBServer_mysql__endpoint" {
  value = aws_db_instance.db.endpoint
}