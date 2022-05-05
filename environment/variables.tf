variable "project" {
  type    = string
  default = "dev-environment"
}

variable "name" {
  type    = string
}
variable "fixity_function_arn" {
  type    = string
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^arn:aws:lambda:", var.fixity_function_arn))
    error_message = "The fixity_function_arn value must be a valid Lambda function ARN."
  }  
}
