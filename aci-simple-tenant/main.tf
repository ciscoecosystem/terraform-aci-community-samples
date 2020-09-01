#Use TF_VAR as a prefix for environmental variables
variable username {}
variable password {}
variable url {}
variable tenant {}
variable bd {}
variable vrf {}
variable bd_subnet {}

provider "aci" {
  username = var.username
  password = var.password
  url      = var.url
  insecure = true
}

resource "aci_tenant" "terraform_ten" {
  name = var.tenant
}

resource "aci_vrf" "vrf1" {
  tenant_dn = aci_tenant.terraform_ten.id
  name      = var.vrf
}

resource "aci_bridge_domain" "bd1" {
  tenant_dn          = aci_tenant.terraform_ten.id
  relation_fv_rs_ctx = aci_vrf.vrf1.name
  name               = var.bd
}

resource "aci_subnet" "bd1_subnet" {
  bridge_domain_dn = aci_bridge_domain.bd1.id
  ip               = var.bd_subnet
}