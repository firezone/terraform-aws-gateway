# Change these to match your environment
locals {
  region         = "us-east-1"
  firezone_token = "<YOUR TOKEN HERE>"
}

module "gateway" {
  source = "firezone/gateway/aws"

  ###################
  # Required inputs #
  ###################

  # Generate a token from the admin portal in Sites -> <site> -> Deploy Gateway.
  # Only one token is needed for the cluster.
  firezone_token = local.firezone_token

  # Pick an AMI to use. We recommend Ubuntu LTS or Amazon Linux 2.
  base_ami = data.aws_ami_ids.ubuntu.ids[0]

  # Attach the Gateways to your VPC and subnets.
  vpc            = aws_vpc.main.id
  private_subnet = aws_subnet.private.id
  instance_security_groups = [
    aws_security_group.instance.id
  ]

  ###################
  # Optional inputs #
  ###################

  # Whether to attach the instances to public IPs.
  # attach_public_ips = true

  # We recommend a minimum of 3 instances for high availability.
  # replicas           = 3

  # Deploy a specific version of the Gateway. Generally, we recommend using the latest version.
  # firezone_version    = "latest"

  # Override the default API URL. This should almost never be needed.
  # firezone_api_url    = "wss://api.firezone.dev"

  # Gateways are very lightweight.
  # See https://www.firezone.dev/kb/deploy/gateways#sizing-recommendations.
  # instance_type       = "t3.nano"
}

data "aws_ami_ids" "ubuntu" {
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

provider "aws" {
  # Change this to your desired region
  region = local.region
}

resource "aws_vpc" "main" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.0.0/24"

  # We will attach a public IP to the instances ourselves.
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.1.0/24"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "instance" {
  vpc_id = aws_vpc.main.id

  // allow SSH from other machines on the subnet
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private.cidr_block,
      aws_subnet.public.cidr_block
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_connect" {
  name        = "allow egress to all vpc subnets"
  description = "Security group to allow SSH to vpc subnets. Created for use with EC2 Instance Connect Endpoint."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private.cidr_block,
      aws_subnet.public.cidr_block
    ]
  }
}

resource "aws_ec2_instance_connect_endpoint" "instance_connect_endpoint" {
  subnet_id          = aws_subnet.public.id
  preserve_client_ip = false
  security_group_ids = [
    aws_security_group.instance_connect.id
  ]

  tags = {
    Name = "firezone-gateway-instance-connect-endpoint"
  }
}

output "gateway_ips" {
  value = module.gateway.public_ips
}
