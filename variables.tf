variable "base_ami" {
  description = "The base AMI for the instances"
  type        = string
}

variable "instance_type" {
  description = "The instance type"
  type        = string
  default     = "t3.nano"
}

variable "replicas" {
  description = "The number of gateway instances to deploy"
  type        = number
  default     = 3
}

variable "firezone_token" {
  description = "The Firezone token"
  type        = string
  nullable    = false
  sensitive   = true
}

variable "firezone_version" {
  description = "The Gateway version to deploy"
  type        = string
  default     = "latest"
}

variable "firezone_name" {
  description = "Name for the Gateways, appears in the admin portal"
  type        = string
  default     = "$(hostname)"
}

variable "firezone_api_url" {
  description = "The Firezone API URL"
  type        = string
  default     = "wss://api.firezone.dev"
}

variable "vpc" {
  description = "The VPC id to use"
  type        = string
}

variable "private_subnet" {
  description = "The private subnet id"
  type        = string
}

variable "attach_public_ips" {
  description = "Whether to attach public IPs to the instances"
  type        = bool
  default     = true
}

variable "instance_security_groups" {
  description = "The security group ids to attach to the instances"
  type        = list(string)
}

variable "extra_tags" {
  description = "Extra tags for the instances"

  type = map(object({
    key                 = string
    value               = string
    propagate_at_launch = bool
  }))

  default = {}
}
