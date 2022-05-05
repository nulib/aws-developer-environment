variable "environments" {
  type    = list(string)
  default = ["dev", "test"]
}

variable "tags" {
  type    = map
  default = {}
}
