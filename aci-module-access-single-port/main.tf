#Use TF_VAR as a prefix for environmental variables
variable "aep_name" {}
variable "password" {}
variable "port_number" {}
variable "port_profile_name" {}
variable "switch_id" {}
variable "switch_profile_name" {}
variable "policy_group_name" {}
variable "url" {}
variable "username" {}
variable "hintfpol_dn" {}
variable "user_physdom_dn" {}

module "baremetal-host" {
  source = "./modules/access-single-port"

  aep_name            = var.aep_name
  password            = var.password
  port_number         = var.port_number
  port_profile_name   = var.port_profile_name
  switch_id           = var.switch_id
  switch_profile_name = var.switch_profile_name
  policy_group_name   = var.policy_group_name
  url                 = var.url
  user_physdom_dn     = var.user_physdom_dn
  username            = var.username
  hintfpol_dn         = var.hintfpol_dn
}

