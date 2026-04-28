output "cognito_hosted_ui_url" {
  description = "Cognito hosted UI base URL"
  value       = "https://${local.cognito_auth_domain}"
}

output "cognito_issuer_url" {
  description = "Cognito OIDC issuer URL — used as the Tailscale OIDC issuer"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tailnet.id}"
}

output "cognito_client_id" {
  description = "Cognito app client ID — enter this during Tailscale OIDC signup"
  value       = aws_cognito_user_pool_client.tailscale.id
}

output "cognito_client_secret" {
  description = "Cognito app client secret — enter this during Tailscale OIDC signup"
  value       = aws_cognito_user_pool_client.tailscale.client_secret
  sensitive   = true
}

output "webfinger_url" {
  description = "WebFinger endpoint — verify this before Tailscale signup"
  value       = "https://${var.domain}/.well-known/webfinger"
}
