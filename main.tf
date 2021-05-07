terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}
# set default region
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}
# nat gateway eip

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "demo"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  create_igw                       = true
  enable_nat_gateway               = true
  single_nat_gateway               = true
  default_vpc_enable_dns_hostnames = true
  default_vpc_enable_dns_support   = true

  create_vpc = true
  tags = {
    Name    = "demo",
    project = "terra_demo"
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "Private_SG"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id


  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "http-80-tcp"
      cidr_blocks = "118.189.0.0/16,116.206.0.0/16,223.25.0.0/16"
    },
  ]
  egress_rules = ["all-all"]
  tags = {
    Name    = "SG",
    project = "terra_demo"
  }
}



resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

}
# store the generate ec2 key on local machine
resource "null_resource" "get_keys" {

  provisioner "local-exec" {
    command = "echo '${tls_private_key.ec2_key.public_key_openssh}' > ./.ssh/public_key.rsa"
  }

  provisioner "local-exec" {
    command = "echo '${tls_private_key.ec2_key.private_key_pem}' > ./.ssh/private_key.pem"
  }

}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "ec2_key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "ec2" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"
  name                   = "demo_ec2"
  instance_count         = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = module.key_pair.key_pair_key_name
  vpc_security_group_ids = [module.security_group.security_group_id]
  # subnet_id              = module.vpc.private_subnets
  subnet_id = tolist(module.vpc.private_subnets)[0]

    user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt install docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
 
  EOF

  tags = {
    Name    = "demo_ec2"
    project = "terra_demo"
  }
}


module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "demo-lb"

  load_balancer_type = "network"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  # security_groups = [module.security_group.security_group_id]

  target_groups = [
    {
      name_prefix      = "http"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
    },
    {
      name_prefix      = "ssh"
      backend_protocol = "TCP"
      backend_port     = 22
      target_type      = "instance"
    },
  ]


  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 22
      protocol           = "TCP"
      target_group_index = 1
    }
  ]

  tags = {
    project = "terra_demo"
  }
}

resource "aws_lb_target_group_attachment" "http" {
  target_group_arn = tolist(module.nlb.target_group_arns)[0]
  target_id        = tolist(module.ec2.id)[0] 
  port             = 80
}
resource "aws_lb_target_group_attachment" "ssh" {
  target_group_arn = tolist(module.nlb.target_group_arns)[1]
  target_id        = tolist(module.ec2.id)[0] 
  port             = 22
}
