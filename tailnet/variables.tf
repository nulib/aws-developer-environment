variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain" {
  description = "The subdomain used for the tailnet and WebFinger endpoint"
  type        = string
}

variable "entra_tenant_id" {
  description = "Your Azure / Entra ID tenant ID"
  type        = string
}

variable "tailscale_callback_urls" {
  description = "Tailscale OIDC callback URLs (obtained after initial tailnet creation). Leave empty during Phase 1."
  type        = list(string)
  default     = ["https://login.tailscale.com/a/oauth_response"]
}