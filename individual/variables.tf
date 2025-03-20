variable "environments" {
  type    = list(string)
  default = ["dev", "test"]
}

variable "ide_instance_type" {
  type    = string
  default = "m5.large"
}

variable "repository_email" {
  type    = string
}

variable "user_tags" {
  type    = map(map(string))
}

variable "tags" {
  type    = map
  default = {}
}
