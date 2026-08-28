resource "aci_tenant" "this" {
  for_each = local.tenants

  name        = each.key
  description = each.value.description
  owner_tag   = each.value.owner_tag
}

resource "aci_application_profile" "this" {
  for_each = local.application_profiles

  parent_dn   = aci_tenant.this[each.value.tenant].id
  name        = each.value.name
  description = each.value.description
}

resource "aci_vrf" "this" {
  for_each = local.vrfs

  parent_dn                            = aci_tenant.this[each.value.tenant].id
  name                                 = each.value.name
  description                          = each.value.description
  policy_control_enforcement_mode      = each.value.policy_control_enforcement_mode
  policy_control_enforcement_direction = each.value.policy_control_enforcement_direction
}

resource "aci_bridge_domain" "this" {
  for_each = local.bridge_domains

  parent_dn                     = aci_tenant.this[each.value.tenant].id
  name                          = each.value.name
  description                   = each.value.description
  bridge_domain_type            = each.value.type
  arp_flooding                  = each.value.arp_flooding
  clear_remote_mac_entries      = each.value.clear_remote_mac_entries
  unicast_routing               = each.value.unicast_routing
  pim                           = each.value.multicast_routing
  ip_learning                   = each.value.ip_learning
  l2_unknown_unicast_flooding   = each.value.l2_unknown_unicast
  l3_unknown_multicast_flooding = each.value.l3_unknown_multicast
  multi_destination_flooding    = each.value.multi_destination_flooding

  relation_to_vrf = {
    vrf_name = aci_vrf.this["${each.value.tenant}/${each.value.vrf}"].name
  }
}

resource "aci_subnet" "this" {
  for_each = local.subnets

  parent_dn   = aci_bridge_domain.this[each.value.bd_key].id
  name_alias  = each.value.name
  description = each.value.description
  ip          = each.value.ip
  scope       = ["private"]
}

resource "aci_application_epg" "this" {
  for_each = local.epgs

  parent_dn              = aci_application_profile.this["${each.value.tenant}/${each.value.ap}"].id
  name                   = each.value.name
  description            = each.value.description
  intra_epg_isolation    = each.value.intra_epg_isolation
  preferred_group_member = each.value.preferred_group_member

  relation_to_bridge_domain = {
    bridge_domain_name = aci_bridge_domain.this["${each.value.tenant}/${each.value.bridge_domain}"].name
  }
}

resource "aci_epg_to_domain" "this" {
  for_each = local.epgs

  application_epg_dn = aci_application_epg.this[each.key].id
  tdn                = aci_physical_domain.this[each.value.physical_domain].id
}
