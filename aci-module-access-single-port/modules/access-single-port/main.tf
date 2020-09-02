variable "aep_name" {}
variable "password" {}
variable "port_number" {}
variable "port_profile_name" {}
variable "switch_id" {}
variable "switch_profile_name" {}
variable "url" {}
variable "username" {}
variable "policy_group_name" {}
variable "hintfpol_dn" {}
variable "user_physdom_dn" {}

provider "aci" {
  username = var.username
  password = var.password
  url      = var.url
  insecure = true
}

resource "aci_lldp_interface_policy" "lldp_on" {
  name        = "tf-lldp-on"
  admin_rx_st = "enabled"
  admin_tx_st = "enabled"
}

resource "aci_rest" "autoneg_10g" {
  path    = "/api/mo/uni/infra.json"
  payload = <<EOF
  fabricHIfPol:
    attributes:
      name: TF-10g
      speed: 10G
  EOF
}

resource "aci_lacp_policy" "lacp_active" {
  name = "tf-lacp-active"
  mode = "active"
  ctrl = "susp-individual"
}

resource "aci_attachable_access_entity_profile" "aep_physical_server" {
  name                    = var.aep_name
  relation_infra_rs_dom_p = [var.user_physdom_dn]
}

resource "aci_leaf_access_port_policy_group" "access_policy_group" {
  name                          = var.policy_group_name
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp_on.id
  relation_infra_rs_h_if_pol    = var.hintfpol_dn
  relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.aep_physical_server.id
}

resource "aci_leaf_interface_profile" "access_port_profile" {
  name = var.port_profile_name
}

resource "aci_access_port_selector" "access_port_selector" {
  leaf_interface_profile_dn      = aci_leaf_interface_profile.access_port_profile.id
  name                           = "interfaces"
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_leaf_access_port_policy_group.access_policy_group.id
}

resource "aci_access_port_block" "acc_port_block" {
  access_port_selector_dn = aci_access_port_selector.access_port_selector.id
  name                    = "block1"
  from_port               = var.port_number
  to_port                 = var.port_number
}

resource "aci_leaf_profile" "access_node_profile" {
  name                         = var.switch_profile_name
  relation_infra_rs_acc_port_p = [aci_leaf_interface_profile.access_port_profile.id]
}

resource "aci_switch_association" "switch_association" {
  leaf_profile_dn         = aci_leaf_profile.access_node_profile.id
  name                    = "tf-leaf-selector"
  switch_association_type = "range"
}

resource "aci_node_block" "node_block" {
  switch_association_dn = aci_switch_association.switch_association.id
  name                  = "nodeblk1"
  from_                 = var.switch_id
  to_                   = var.switch_id
}