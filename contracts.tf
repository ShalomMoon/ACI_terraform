resource "aci_filter" "this" {
  for_each = local.filters

  tenant_dn = aci_tenant.this[each.value.tenant].id
  name      = each.value.name
}

resource "aci_filter_entry" "this" {
  for_each = local.filter_entries

  filter_dn   = aci_filter.this[each.value.filter_key].id
  name        = each.value.name
  ether_t     = each.value.ether_type
  prot        = each.value.protocol
  d_from_port = tostring(each.value.destination_port_start)
  d_to_port   = tostring(each.value.destination_port_end)
}

resource "aci_contract" "this" {
  for_each = local.contracts

  tenant_dn = aci_tenant.this[each.value.tenant].id
  name      = each.value.name
  scope     = each.value.scope
}

resource "aci_contract_subject" "this" {
  for_each = local.contract_subjects

  contract_dn   = aci_contract.this[each.value.contract_key].id
  name          = each.value.name
  rev_flt_ports = each.value.reverse_filter_ports
}

resource "aci_contract_subject_filter" "this" {
  for_each = local.subject_filters

  contract_subject_dn = aci_contract_subject.this[each.value.subject_key].id
  filter_dn           = aci_filter.this[each.value.filter_key].id
  action              = "permit"
  directives          = ["none"]
}

resource "aci_epg_to_contract" "this" {
  for_each = local.epg_contracts

  application_epg_dn = aci_application_epg.this[each.value.epg_key].id
  contract_dn        = aci_contract.this[each.value.contract_key].id
  contract_type      = each.value.type
}
