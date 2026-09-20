# variables.tf
variable "proyecto"     { type = string }
variable "prefijo"      { type = string }
variable "region"       { type = string  default = "us-central1" }
variable "cidr_publica" { type = string  default = "10.10.1.0/24" }