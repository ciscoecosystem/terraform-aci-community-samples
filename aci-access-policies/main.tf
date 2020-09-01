#Use TF_VAR as a prefix for environmental variables
variable username {}
variable password {}
variable url {}
variable aep_name {}
variable vpc_policy_group_name {}
variable port_profile_name {}
variable port_number {}
variable switch_profile_name {}
variable switch_A_id {}
variable switch_B_id {}
variable explicit_protection_group_name {}
variable vpc_domain_id {}

locals {
  user_physdom_dn = "uni/phys-phys"
  hintfpol = "/uni/infra/hintfpol-TF-10g"
}

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
  relation_infra_rs_dom_p = [local.user_physdom_dn]
}

resource "aci_vpc_explicit_protection_group" "vpc_domain" {
  name                             = var.explicit_protection_group_name
  switch1                          = var.switch_A_id
  switch2                          = var.switch_B_id
  vpc_explicit_protection_group_id = var.vpc_domain_id
}

resource "aci_pcvpc_interface_policy_group" "vpc_policy_group" {
  name                          = var.vpc_policy_group_name
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.lldp_on.id
  relation_infra_rs_h_if_pol    = local.hintfpol
  relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.aep_physical_server.id
  lag_t                         = "node"
}

resource "aci_leaf_interface_profile" "vpc_acc_port_profile" {
  name = var.port_profile_name
}

resource "aci_access_port_selector" "vpc_acc_port_selector" {
  leaf_interface_profile_dn      = aci_leaf_interface_profile.vpc_acc_port_profile.id
  name                           = "interfaces"
  access_port_selector_type      = "range"
  relation_infra_rs_acc_base_grp = aci_pcvpc_interface_policy_group.vpc_policy_group.id
}

resource "aci_access_port_block" "vpc_acc_port_block" {
  access_port_selector_dn = aci_access_port_selector.vpc_acc_port_selector.id
  name                    = "block1"
  from_port               = var.port_number
  to_port                 = var.port_number
}

resource "aci_leaf_profile" "vpc_node_profile" {
  name                         = var.switch_profile_name
  relation_infra_rs_acc_port_p = [aci_leaf_interface_profile.vpc_acc_port_profile.id]
}

resource "aci_switch_association" "vpc_pair_association" {
  leaf_profile_dn         = aci_leaf_profile.vpc_node_profile.id
  name                    = "tf-leaf-selector"
  switch_association_type = "range"
}

resource "aci_node_block" "vpc_pair_block" {
  switch_association_dn = aci_switch_association.vpc_pair_association.id
  name                  = "nodeblk-multi1"
  from_                 = var.switch_A_id
  to_                   = var.switch_B_id
}

