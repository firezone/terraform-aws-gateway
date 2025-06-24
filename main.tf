resource "aws_instance" "gateway" {
  availability_zone = var.availability_zone
  count             = var.replicas
  ami               = var.base_ami
  instance_type     = var.instance_type
  subnet_id         = var.private_subnet
  security_groups   = var.instance_security_groups

  # We will attach a public IP to the instances ourselves.
  # Intended to minimize IP churn.
  associate_public_ip_address = false

  user_data = base64encode(<<-EOF
  #!/bin/bash
  set -e

  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update
  sudo apt-get install -y curl iptables

  FIREZONE_TOKEN="${var.firezone_token}" \
  FIREZONE_VERSION="${var.firezone_version}" \
  FIREZONE_NAME="${var.firezone_name}" \
  FIREZONE_ID="$(head -c /dev/urandom | sha256)" \
  FIREZONE_API_URL="${var.firezone_api_url}" \
  bash <(curl -fsSL https://raw.githubusercontent.com/firezone/firezone/main/scripts/gateway-systemd-install.sh)

  EOF
  )

  tags = merge({
    Name = "firezone-gateway-instance"
  }, var.extra_tags)
}

# Associate the Elastic IPs with the Gateway instances.
resource "aws_eip_association" "gateway" {
  count         = length(var.aws_eip_ids)
  instance_id   = aws_instance.gateway[count.index].id
  allocation_id = var.aws_eip_ids[count.index]

  lifecycle {
    precondition {
      condition     = length(var.aws_eip_ids) == 0 || length(var.aws_eip_ids) == var.replicas
      error_message = "The number of EIPs must match the number of Gateway instances."
    }
  }
}
