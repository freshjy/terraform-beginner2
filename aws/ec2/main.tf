terraform {
  required_version = ">=1.9.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.73.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  # owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "my-ec2" {
  count                       = 3
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = t2.small
  key_name                    = aws_key_pair.my-key_pair.key_name
  subnet_id                   = module.my_vpc.public_subnet_ids[count.index]
  vpc_security_group_ids      = [aws_security_group.my_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "MyFirstInstance-${count.index + 1}"
  }

  lifecycle {
    create_before_destroy = true
  }
}


# 랜덤한 문자열 생성 (Key Pair 이름 구성에 사용)
resource "random_string" "key_name_suffix" {
  length  = 8     # 랜덤 문자열 길이 설정
  special = false # 특수 문자 제외
  upper   = false # 대문자 제외
}

# 공개 키 파일 읽기
data "local_file" "public_key" {
  filename = pathexpand("~/.ssh/my-key.pub") # 로컬 공개 키 파일 경로 설정
}

# 랜덤 문자열을 포함한 Key Pair 이름 생성
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my-key-${random_string.key_name_suffix.result}" # 랜덤한 이름 생성
  public_key = data.local_file.public_key.content               # 공개 키 설정

  tags = {
    Name = "MyKeyPair-${random_string.key_name_suffix.result}" # Key Pair 이름 태그
  }
}

locals {
  aws_zone_mapping = {
    "us-east-1" = ["a", "b", "c"]
  }
  azs = [for az in local.aws_zone_mapping[var.aws_region] : "${var.aws_region}${az}"]
}

module "my_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.15.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "my_sg" {
  vpc_id = module.my_vpc.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

