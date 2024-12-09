variable "region" {
  type        = string
  description = "AWS region"
}
variable "profile" {
  type        = string
  description = "AWS profile"
}

variable "home_global_ip" {
  type = string
}
variable "home_network_cidr" {
  type = string
}
variable "home_pi_private_ip" {
  type = string
}
variable "node_network_cidr" {
  type = string
}
variable "pod_network_cidr" {
  type = string
}
