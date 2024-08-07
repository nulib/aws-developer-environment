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

variable "dc_api_url" {
  type    = string
}

variable "dc_api_ttl" {
  type    = number
}

variable "dc_api_secret" {
  type    = string
}

variable "model_repository" {
  type    = string
}

variable "model_requirements" {
  type    = list(string)
}

variable "sagemaker_inference_memory" {
  type    = number
  default = 4096
}

variable "sagemaker_inference_provisioned_concurrency" {
  type    = number
  default = 0
}

variable "sagemaker_inference_max_concurrency" {
  type    = number
  default = 20
}
