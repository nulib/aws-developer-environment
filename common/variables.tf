variable "hosted_zone_name" {
  type    = string
  default = "dev.rdc.library.northwestern.edu"
}

variable "lambda_path" {
  type    = string
  default = "../../meadow/priv/nodejs"
}

variable "developer_certificate" {
  type    = string
}

variable "developer_key" {
  type    = string
}
