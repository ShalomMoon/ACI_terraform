resource "aci_epg_to_static_path" "this" {
  for_each = local.static_bindings

  application_epg_dn = aci_application_epg.this[each.value.epg_key].id
  tdn                = "topology/pod-${each.value.pod}/paths-${each.value.leaf}/pathep-[eth1/${each.value.port}]"
  encap              = "vlan-${each.value.vlan}"
  instr_imedcy       = each.value.deploy_immediacy
  mode               = each.value.mode
}
