variable "hosted_zone_name" {
  type    = string
  default = "dev.rdc.library.northwestern.edu"
}

variable "lambda_path" {
  type    = string
  default = "../../meadow/lambdas"
}

# Secrets

variable "config_secrets" {
  type    = map(map(any))
}

variable "ldap_config" {
  type    = map(any)
}

variable "ssl_certificate_file" {
  type    = string
}

variable "ssl_key_file" {
  type    = string
}

variable "acme_cert_state_store" {
  type    = map(string)
}