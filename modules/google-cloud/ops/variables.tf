variable "project_id" {
  description = "The ID of the project in which the resource belongs."
}

variable "slack_alerts_channel" {
  type        = string
  description = "Slack channel which will receive monitoring alerts"
}

variable "slack_alerts_auth_token" {
  type        = string
  description = "Slack auth token for the infra alerts channel"
  sensitive   = true
}

variable "pagerduty_auth_token" {
  type        = string
  description = "Pagerduty auth token for the infra alerts channel"
  default     = null
  sensitive   = true
}

variable "additional_notification_channels" {
  type        = list(string)
  default     = []
  description = "List of mobile app notification channels"
}

variable "api_host" {
  type = string
}

variable "web_host" {
  type = string
}
