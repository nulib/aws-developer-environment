variable "hosted_zone_name" {
  type    = string
  default = "dev.rdc.library.northwestern.edu"
}

variable "lambda_path" {
  type    = string
  default = "../../meadow/lambdas"
}

variable "staging_vpc_id" {
  type    = string
}

# Secrets

variable "config_secrets" {
  type    = map(map(any))
}
variable "ssl_certificate_file" {
  type    = string
}

variable "ssl_key_file" {
  type    = string
}

variable "acme_cert_actions_repos" {
  type    = list(string)
}

variable "acme_cert_state_store" {
  type    = map(string)
}

variable "dc_api_url" {
  type    = string
}

variable "dc_api_ttl" {
  type    = number
}

variable "dc_api_secret" {
  type    = string
}

variable "embedding_model_name" {
  type    = string
}

variable "embedding_dimensions" {
  type    = number
}
