variable "tailnet" {
  description = "Tailnet name"
  type        = string
}

variable "tailscale_api_key" {
  description = "Tailscale API Key"
  type        = string
  sensitive   = true
}

variable "waf_ip_set_name" {
  description = "Name of the WAF IP Set to allow Tailnet IPs"
  type        = string
}