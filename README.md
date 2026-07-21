# Firezone Gateway module for AWS

Deploys one or more [Firezone](https://www.firezone.dev) Gateways as EC2
instances in an existing VPC. Each instance installs the Gateway on first boot
using the official
[systemd install script](https://github.com/firezone/firezone/blob/main/scripts/gateway-systemd-install.sh)
and registers itself with your Firezone account.

## Prerequisites

- A Firezone account with a Site to deploy Gateways into. Generate deploy
  tokens from the admin portal under **Sites → \<site\> → Deploy Gateway**.
- An existing VPC with a subnet for the instances and egress to the internet
  (Internet Gateway or NAT) so the Gateways can reach the Firezone API.
- A Debian-based AMI (Ubuntu LTS recommended) — the install step uses
  `apt-get`.

## Usage

```hcl
module "gateway" {
  source = "firezone/gateway/aws"

  # One single-owner token per Gateway instance; one instance is deployed
  # per token.
  firezone_tokens = var.firezone_tokens

  base_ami          = data.aws_ami_ids.ubuntu.ids[0]
  availability_zone = "us-east-1a"

  vpc                      = aws_vpc.main.id
  private_subnet           = aws_subnet.private.id
  instance_security_groups = [aws_security_group.instance.id]
}
```

See [examples/internet-gateway](./examples/internet-gateway) for a complete
working example including the VPC, routing, security groups, and Elastic IPs.

### Legacy: multi-owner token

Multi-owner tokens are considered legacy and should only be used for existing
deployments. A single token is shared by every Gateway instance, and the
instance count is set with `replicas`:

```hcl
module "gateway" {
  source = "firezone/gateway/aws"

  # A single multi-owner token shared by all Gateway instances (legacy).
  firezone_token = var.firezone_token
  replicas       = 3

  base_ami          = data.aws_ami_ids.ubuntu.ids[0]
  availability_zone = "us-east-1a"

  vpc                      = aws_vpc.main.id
  private_subnet           = aws_subnet.private.id
  instance_security_groups = [aws_security_group.instance.id]
}
```

## Token modes

The module supports both Firezone token types. Set exactly one of the two
variables:

| Mode | Variable | Behavior |
|------|----------|----------|
| Single-owner (default) | `firezone_tokens` | One token per instance; one Gateway instance is deployed per token in the list. Each token can only be used by one connected Gateway at a time. |
| Multi-owner (legacy) | `firezone_token` | A single token shared by every Gateway instance in the cluster; the instance count is set with `replicas`. |

Single-owner tokens are the default way to deploy Gateways. Multi-owner tokens
are considered legacy and are supported for existing deployments only; new
deployments should use single-owner tokens.

With single-owner tokens, the number of Gateway instances is determined by the
length of the token list — to scale up, append tokens; to scale down, remove
tokens from the end. Do not set `replicas` in this mode. Tokens are assigned
to instances by list position: `firezone_tokens[0]` goes to instance `0`, and
so on. A single-owner token can be reused by a replacement instance once the
previous Gateway using it has disconnected from the portal. When changing the
list, replace tokens in place rather than removing entries from the middle —
removing a middle entry shifts every token after it to a different instance
and forces those instances to be replaced.

## High availability

Deploy at least 3 replicas for high availability. Gateways in the same Site
automatically load-balance and fail over. See the
[Gateway deployment docs](https://www.firezone.dev/kb/deploy/gateways) for
sizing and architecture recommendations.

## Upgrading and instance replacement

The Firezone token and other settings are passed via `user_data`, so changing
`firezone_version`, tokens, or logging settings **replaces the instances**.
This is safe for connectivity as long as other Gateways in the Site remain
online, but plan for it in production: Terraform may replace all instances in
parallel. Pinning `firezone_version`
(rather than `latest`) keeps replacements reproducible.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `base_ami` | The base AMI for the instances. This module assumes a Debian-based AMI. | `string` | n/a | yes |
| `availability_zone` | The availability zone to deploy the instances in. | `string` | n/a | yes |
| `vpc` | The VPC id to use. | `string` | n/a | yes |
| `private_subnet` | The private subnet id. | `string` | n/a | yes |
| `instance_security_groups` | The security group ids to attach to the instances. | `list(string)` | n/a | yes |
| `firezone_tokens` | A list of single-owner Firezone tokens, one per Gateway instance. One instance is deployed per token. Mutually exclusive with `firezone_token`. | `list(string)` | `null` | one of |
| `firezone_token` | A multi-owner Firezone token shared by all Gateway instances (legacy). Mutually exclusive with `firezone_tokens`. | `string` | `null` | one of |
| `replicas` | The number of Gateway instances to deploy when using `firezone_token` (legacy). Must not be set with `firezone_tokens`. | `number` | `3` | no |
| `instance_type` | The instance type. Gateways are lightweight; see [sizing recommendations](https://www.firezone.dev/kb/deploy/gateways#sizing-recommendations). | `string` | `"t3.nano"` | no |
| `firezone_version` | The Gateway version to deploy. | `string` | `"latest"` | no |
| `firezone_name` | Name for the Gateways, appears in the admin portal. | `string` | `"$(hostname)"` | no |
| `firezone_api_url` | The Firezone API URL. | `string` | `"wss://api.firezone.dev"` | no |
| `attach_public_ips` | Whether to attach public IPs to the instances. | `bool` | `true` | no |
| `aws_eip_ids` | Elastic IP ids to attach to the instances. Must be the same length as `replicas` if provided. | `list(string)` | `[]` | no |
| `log_level` | Sets `RUST_LOG` for the Gateway process. | `string` | `"info"` | no |
| `log_format` | Sets `FIREZONE_LOG_FORMAT`. Either `human` or `json`. | `string` | `"human"` | no |
| `enable_flow_logs` | Sets `FIREZONE_FLOW_LOGS=true` for the Gateway when enabled. | `bool` | `false` | no |
| `extra_tags` | Extra tags for the instances. | `map(string)` | `{}` | no |

## Outputs

This module currently exposes no outputs.

## Examples

- [Internet Gateway](./examples/internet-gateway): Deploy one or more Firezone
  Gateways in a single AWS VPC configured with an Internet Gateway for egress.
  The Gateways are associated with dedicated Elastic IPs to minimize IP churn.
  Read this if you're looking to deploy Firezone Gateways to AWS that need to
  communicate with the internet using static IPs.

## License

See [LICENSE](./LICENSE).
