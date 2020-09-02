#Use TF_VAR as a prefix for environmental variables
variable "username" {}
variable "url" {}
variable "private_key" {}
variable "cert_name" {}
variable "border_leaf_id" {}
variable "enable_router_id_loopback" {}
variable "router_id" {}
variable "interface_path_dn" {}
variable "border_leaf_profile_name" {}
variable "svi_ip_address" {}
variable "ext_vlan_encap" {}
variable "fabric_node_dn" {}
variable "interface_id" {
  default = "eth1/25"
}
variable "l3_domain_name" {
}
variable "external_epg_prefix" {
  default = "0.0.0.0/0"
}
variable "external_epg" {
  default = "tf-external-epg"
}
variable "l3_external_prov_contract" {
  default = ["uni/tn-common/brc-default"]
}
variable "destination_network" {
  default = "0.0.0.0/0"
}
variable "gateway" {
}

provider "aci" {
  username    = var.username
  private_key = var.private_key
  cert_name   = var.cert_name
  url         = var.url
  insecure    = true
}

data "aci_tenant" "common_tenant" {
  name = "common"
}

data "aci_vrf" "common_vrf" {
  tenant_dn = data.aci_tenant.common_tenant.id
  name      = "default"
}

data "aci_l3_domain_profile" "l3_domain" {
  name = var.l3_domain_name
}

resource "aci_l3_outside" "l3_out" {
  tenant_dn                    = data.aci_tenant.common_tenant.id
  name                         = "tf-static-l3-out"
  relation_l3ext_rs_ectx       = data.aci_vrf.common_vrf.id
  relation_l3ext_rs_l3_dom_att = data.aci_l3_domain_profile.l3_domain.id
}

resource "aci_logical_node_profile" "border_leaf_profile" {
  l3_outside_dn = aci_l3_outside.l3_out.id
  name          = var.border_leaf_profile_name
}

resource "aci_logical_node_to_fabric_node" "border_leaf_rs" {
  logical_node_profile_dn = aci_logical_node_profile.border_leaf_profile.id
  #tdn = "topology/pod-1/node-304"
  tdn              = var.fabric_node_dn
  rtr_id           = var.router_id
  rtr_id_loop_back = var.enable_router_id_loopback
}

resource "aci_logical_interface_profile" "border_leaf_logical_int_profile" {
  logical_node_profile_dn           = aci_logical_node_profile.border_leaf_profile.id
  name                              = "tf-to-wan"
  relation_l3ext_rs_path_l3_out_att = [var.interface_path_dn]
}

resource "aci_rest" "logical_interface_rs_path" {

  path       = "/api/mo/${aci_logical_interface_profile.border_leaf_logical_int_profile.id}/rspathL3OutAtt-[${var.interface_path_dn}].json"
  class_name = "l3extRsPathL3OutAtt"
  content = {
    "ifInstT" = "ext-svi"
    "encap"   = var.ext_vlan_encap
    "addr"    = var.svi_ip_address
  }
}

resource "aci_external_network_instance_profile" "external_epg" {
  l3_outside_dn       = aci_l3_outside.l3_out.id
  name                = var.external_epg
  relation_fv_rs_prov = var.l3_external_prov_contract
}

resource "aci_l3_ext_subnet" "external_subnet" {
  external_network_instance_profile_dn = aci_external_network_instance_profile.external_epg.id
  ip                                   = var.external_epg_prefix
}

resource "aci_rest" "destination_network" {
  depends_on = [aci_logical_node_to_fabric_node.border_leaf_rs]
  path       = "/api/mo/${aci_logical_node_profile.border_leaf_profile.id}/rsnodeL3OutAtt-[${var.fabric_node_dn}]/rt-[${var.destination_network}].json"
  class_name = "ipRouteP"
  content = {
    "ip"    = var.destination_network
  }
}

resource "aci_rest" "gateway" {
  depends_on = [aci_rest.destination_network]
  path       = "/api/mo/${aci_logical_node_profile.border_leaf_profile.id}/rsnodeL3OutAtt-[${var.fabric_node_dn}]/rt-[${var.destination_network}]/nh-[${var.gateway}].json"
  class_name = "ipNexthopP"
  content = {
    "nhAddr" = var.gateway
  }
}










