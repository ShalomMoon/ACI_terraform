locals {
  config = yamldecode(file("${path.module}/${var.configuration_file}"))

  fabric = local.config.fabric
  tenants = {
    for tenant_name, tenant in local.config.tenants : tenant_name => merge(tenant, {
      name = tenant_name
    })
  }

  application_profiles = merge([
    for tenant_name, tenant in local.tenants : {
      for ap_name, ap in tenant.application_profiles :
      "${tenant_name}/${ap_name}" => merge(ap, {
        tenant = tenant_name
        name   = ap_name
      })
    }
  ]...)

  vrfs = merge([
    for tenant_name, tenant in local.tenants : {
      for vrf_name, vrf in tenant.vrfs :
      "${tenant_name}/${vrf_name}" => merge(vrf, {
        tenant = tenant_name
        name   = vrf_name
      })
    }
  ]...)

  bridge_domains = merge([
    for tenant_name, tenant in local.tenants : {
      for bd_name, bd in tenant.bridge_domains :
      "${tenant_name}/${bd_name}" => merge(bd, {
        tenant = tenant_name
        name   = bd_name
      })
    }
  ]...)

  subnets = merge([
    for bd_key, bd in local.bridge_domains : {
      for subnet in bd.subnets :
      "${bd_key}/${subnet.ip}" => merge(subnet, {
        bd_key = bd_key
      })
    }
  ]...)

  epgs = merge([
    for tenant_name, tenant in local.tenants : merge([
      for ap_name, ap in tenant.application_profiles : {
        for epg_name, epg in try(ap.epgs, {}) :
        "${tenant_name}/${ap_name}/${epg_name}" => merge(epg, {
          tenant = tenant_name
          ap     = ap_name
          name   = epg_name
        })
      }
    ]...)
  ]...)

  filters = merge([
    for tenant_name, tenant in local.tenants : {
      for filter_name, filter in tenant.filters :
      "${tenant_name}/${filter_name}" => merge(filter, {
        tenant = tenant_name
        name   = filter_name
      })
    }
  ]...)

  filter_entries = merge([
    for filter_key, filter in local.filters : {
      for entry in filter.entries :
      "${filter_key}/${entry.name}" => merge(entry, {
        filter_key = filter_key
      })
    }
  ]...)

  contracts = merge([
    for tenant_name, tenant in local.tenants : {
      for contract_name, contract in tenant.contracts :
      "${tenant_name}/${contract_name}" => merge(contract, {
        tenant = tenant_name
        name   = contract_name
      })
    }
  ]...)

  contract_subjects = merge([
    for contract_key, contract in local.contracts : {
      for subject_name, subject in contract.subjects :
      "${contract_key}/${subject_name}" => merge(subject, {
        contract_key = contract_key
        name         = subject_name
      })
    }
  ]...)

  subject_filters = merge([
    for subject_key, subject in local.contract_subjects : {
      for filter_name in subject.filters :
      "${subject_key}/${filter_name}" => {
        subject_key = subject_key
        filter_key  = "${local.contracts[subject.contract_key].tenant}/${filter_name}"
      }
    }
  ]...)

  epg_contracts = merge([
    for contract_key, contract in local.contracts : {
      for binding in contract.epg_bindings :
      "${contract_key}/${binding.application_profile}/${binding.epg}/${binding.type}" => merge(binding, {
        contract_key = contract_key
        epg_key      = "${contract.tenant}/${binding.application_profile}/${binding.epg}"
      })
    }
  ]...)

  static_binding_groups = flatten([
    for tenant_name, tenant in local.tenants : flatten([
      for ap_name, ap in tenant.application_profiles : [
        for epg_name, epg in try(ap.epgs, {}) : merge(epg.static_bindings, {
          epg_key = "${tenant_name}/${ap_name}/${epg_name}"
        }) if try(epg.static_bindings, null) != null
      ]
    ])
  ])

  static_bindings = merge(flatten([
    for group in local.static_binding_groups : [
      for leaf in group.leafs : {
        for port in range(group.port_start, group.port_end + 1) :
        "${group.epg_key}/pod-${group.pod}/leaf-${leaf}/eth1-${port}" => {
          epg_key          = group.epg_key
          pod              = group.pod
          leaf             = leaf
          port             = port
          vlan             = group.vlan
          mode             = try(group.mode, "regular")
          deploy_immediacy = try(group.deploy_immediacy, "lazy")
        }
      }
    ]
  ])...)

  interface_selectors = merge([
    for profile_name, profile in local.fabric.interface_profiles : {
      for selector in profile.selectors :
      "${profile_name}/${selector.name}" => merge(selector, {
        profile = profile_name
      })
    }
  ]...)
}
