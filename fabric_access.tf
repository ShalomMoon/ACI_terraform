resource "aci_vlan_pool" "this" {
  for_each = local.fabric.vlan_pools

  name        = each.key
  description = each.value.description
  alloc_mode  = each.value.allocation_mode
}

resource "aci_ranges" "this" {
  for_each = local.fabric.vlan_pools

  vlan_pool_dn = aci_vlan_pool.this[each.key].id
  description  = each.value.range.description
  from         = "vlan-${each.value.range.start}"
  to           = "vlan-${each.value.range.end}"
  alloc_mode   = each.value.range.allocation_mode
}

resource "aci_physical_domain" "this" {
  for_each = local.fabric.physical_domains

  name                      = each.key
  relation_infra_rs_vlan_ns = aci_vlan_pool.this[each.value.vlan_pool].id
}

resource "aci_attachable_access_entity_profile" "this" {
  for_each = local.fabric.aaeps

  name        = each.key
  description = each.value.description
}

resource "aci_aaep_to_domain" "this" {
  for_each = {
    for pair in flatten([
      for aaep_name, aaep in local.fabric.aaeps : [
        for domain_name in aaep.physical_domains : {
          key         = "${aaep_name}/${domain_name}"
          aaep_name   = aaep_name
          domain_name = domain_name
        }
      ]
    ]) : pair.key => pair
  }

  attachable_access_entity_profile_dn = aci_attachable_access_entity_profile.this[each.value.aaep_name].id
  domain_dn                           = aci_physical_domain.this[each.value.domain_name].id
}

resource "aci_cdp_interface_policy" "this" {
  for_each = local.fabric.interface_policies.cdp

  name        = each.key
  admin_state = each.value.admin_state
}

resource "aci_lldp_interface_policy" "this" {
  for_each = local.fabric.interface_policies.lldp

  name           = each.key
  receive_state  = each.value.receive_state
  transmit_state = each.value.transmit_state
}

resource "aci_link_level_interface_policy" "this" {
  for_each = local.fabric.interface_policies.link_level

  name             = each.key
  description      = each.value.description
  auto_negotiation = each.value.auto_negotiation
  speed            = each.value.speed
}

resource "aci_mcp_interface_policy" "this" {
  for_each = local.fabric.interface_policies.mcp

  name        = each.key
  description = each.value.description
  admin_state = each.value.admin_state
}

resource "aci_lacp_policy" "this" {
  for_each = local.fabric.interface_policies.lacp

  name      = each.key
  mode      = each.value.mode
  min_links = tostring(each.value.min_links)
  max_links = tostring(each.value.max_links)
}

resource "aci_leaf_access_port_policy_group" "access" {
  for_each = {
    for name, group in local.fabric.policy_groups : name => group
    if group.type == "access"
  }

  name                          = each.key
  description                   = each.value.description
  relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.this[each.value.aaep].id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.this[each.value.cdp_policy].id
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.this[each.value.lldp_policy].id
  relation_infra_rs_h_if_pol    = aci_link_level_interface_policy.this[each.value.link_level_policy].id
  relation_infra_rs_mcp_if_pol  = aci_mcp_interface_policy.this[each.value.mcp_policy].id
}

resource "aci_leaf_access_bundle_policy_group" "bundle" {
  for_each = {
    for name, group in local.fabric.policy_groups : name => group
    if group.type == "vpc"
  }

  name                          = each.key
  description                   = each.value.description
  lag_t                         = "node"
  relation_infra_rs_att_ent_p   = aci_attachable_access_entity_profile.this[each.value.aaep].id
  relation_infra_rs_cdp_if_pol  = aci_cdp_interface_policy.this[each.value.cdp_policy].id
  relation_infra_rs_lldp_if_pol = aci_lldp_interface_policy.this[each.value.lldp_policy].id
  relation_infra_rs_h_if_pol    = aci_link_level_interface_policy.this[each.value.link_level_policy].id
  relation_infra_rs_mcp_if_pol  = aci_mcp_interface_policy.this[each.value.mcp_policy].id
  relation_infra_rs_lacp_pol    = aci_lacp_policy.this[each.value.lacp_policy].id
}

resource "aci_vpc_explicit_protection_group" "this" {
  for_each = local.fabric.vpc_protection_groups

  name                             = each.key
  switch1                          = tostring(each.value.switch1)
  switch2                          = tostring(each.value.switch2)
  vpc_explicit_protection_group_id = tostring(each.value.id)
}

resource "aci_leaf_interface_profile" "this" {
  for_each = local.fabric.interface_profiles

  name        = each.key
  description = each.value.description
}

resource "aci_access_port_selector" "this" {
  for_each = local.interface_selectors

  parent_dn          = aci_leaf_interface_profile.this[each.value.profile].id
  name               = each.value.name
  description        = each.value.description
  port_selector_type = "range"

  relation_to_leaf_access_port_policy_group = {
    target_dn = each.value.policy_group_type == "vpc" ? aci_leaf_access_bundle_policy_group.bundle[each.value.policy_group].id : aci_leaf_access_port_policy_group.access[each.value.policy_group].id
  }
}

resource "aci_access_port_block" "this" {
  for_each = local.interface_selectors

  parent_dn = aci_access_port_selector.this[each.key].id
  name      = each.value.block_name
  from_card = tostring(each.value.card)
  to_card   = tostring(each.value.card)
  from_port = tostring(each.value.port)
  to_port   = tostring(each.value.port)
}

resource "aci_leaf_profile" "this" {
  for_each = local.fabric.leaf_profiles

  name                         = each.key
  description                  = each.value.description
  relation_infra_rs_acc_port_p = [for profile in each.value.interface_profiles : aci_leaf_interface_profile.this[profile].id]
}

resource "aci_leaf_selector" "this" {
  for_each = local.fabric.leaf_profiles

  leaf_profile_dn         = aci_leaf_profile.this[each.key].id
  name                    = "${each.key}_selector"
  switch_association_type = "range"
}

resource "aci_node_block" "this" {
  for_each = local.fabric.leaf_profiles

  switch_association_dn = aci_leaf_selector.this[each.key].id
  name                  = "${each.key}_nodes"
  from_                 = tostring(each.value.node_from)
  to_                   = tostring(each.value.node_to)
}
