locals {
  # In single-owner mode the instance count comes from the token list;
  # in legacy multi-owner mode it comes from var.replicas (default 3).
  replicas = var.firezone_tokens != null ? length(var.firezone_tokens) : coalesce(var.replicas, 3)
}

resource "aws_instance" "gateway" {
  availability_zone = var.availability_zone
  count             = local.replicas
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

  export FIREZONE_TOKEN="${var.firezone_tokens != null ? var.firezone_tokens[count.index] : var.firezone_token}"
  export FIREZONE_VERSION="${var.firezone_version}"
  export FIREZONE_NAME="${var.firezone_name}"
  export FIREZONE_ID="$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1)"
  export FIREZONE_API_URL="${var.firezone_api_url}"
  export FIREZONE_LOG_FORMAT="${var.log_format}"
%{if var.enable_flow_logs~}
  export FIREZONE_FLOW_LOGS="true"
%{endif~}
  export RUST_LOG="${var.log_level}"
  bash <(curl -fsSL https://raw.githubusercontent.com/firezone/firezone/main/scripts/gateway-systemd-install.sh)

  EOF
  )

  tags = merge({
    Name = "firezone-gateway-instance"
  }, var.extra_tags)

  lifecycle {
    precondition {
      condition     = (var.firezone_token != null) != (var.firezone_tokens != null)
      error_message = "Exactly one of firezone_token (multi-owner) or firezone_tokens (single-owner, one per instance) must be set."
    }

    precondition {
      condition     = var.firezone_tokens == null || var.replicas == null
      error_message = "replicas cannot be set when firezone_tokens is used; the number of instances is determined by the length of the token list."
    }
  }
}

# Associate the Elastic IPs with the Gateway instances.
resource "aws_eip_association" "gateway" {
  count         = length(var.aws_eip_ids)
  instance_id   = aws_instance.gateway[count.index].id
  allocation_id = var.aws_eip_ids[count.index]

  lifecycle {
    precondition {
      condition     = length(var.aws_eip_ids) == 0 || length(var.aws_eip_ids) == local.replicas
      error_message = "The number of EIPs must match the number of Gateway instances."
    }
  }
}
