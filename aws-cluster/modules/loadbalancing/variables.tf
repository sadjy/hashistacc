variable "namespace" {
  type = string
}

variable "vpc" {
    type = any
}

variable "sg" {
  type = any
}

variable "domain" {
  type = string
  default = null
}