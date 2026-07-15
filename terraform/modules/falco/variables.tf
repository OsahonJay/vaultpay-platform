variable "slack_webhook_url" {
  description = "Slack webhook URL for Falco alerts"
  type        = string
  default     = ""
  sensitive   = true
}
