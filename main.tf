resource "aws_instance" "gateway" {
  count           = var.replicas
  ami             = var.base_ami
  instance_type   = var.instance_type
  subnet_id       = var.private_subnet
  security_groups = var.instance_security_groups

  # We will attach a public IP to the instances ourselves.
  # Intended to minimize IP churn.
  associate_public_ip_address = false

  user_data = base64encode(<<-EOF
  #!/bin/bash
  set -e

  sudo apt-get update
  sudo apt-get install -y curl uuid-runtime

  FIREZONE_TOKEN="${var.firezone_token}" \
  FIREZONE_VERSION="${var.firezone_version}" \
  FIREZONE_NAME="${var.firezone_name}" \
  FIREZONE_ID="$(uuidgen)" \
  FIREZONE_API_URL="${var.firezone_api_url}" \
  bash <(curl -fsSL https://raw.githubusercontent.com/firezone/firezone/main/scripts/gateway-systemd-install.sh)

  EOF
  )

  tags = merge({
    Name = "firezone-gateway-instance"
  }, var.extra_tags)
}

# Create one Elastic IP per Gateway instance.
resource "aws_eip" "gateway" {
  count  = var.replicas
  domain = "vpc"
}

# Associate the Elastic IPs with the Gateway instances.
resource "aws_eip_association" "gateway" {
  count         = var.replicas
  instance_id   = aws_instance.gateway[count.index].id
  allocation_id = aws_eip.gateway[count.index].id
}

# Output the Elastic IPs for the Gateway instances.
output "public_ips" {
  description = "The public IPs of the Gateway instances"
  value       = aws_eip.gateway[*].public_ip
}
