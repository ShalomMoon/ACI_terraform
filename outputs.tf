output "managed_tenants" {
  description = "Tenant distinguished names managed by this configuration."
  value       = { for name, tenant in aci_tenant.this : name => tenant.id }
}

output "managed_epgs" {
  description = "Application EPG distinguished names managed by this configuration."
  value       = { for name, epg in aci_application_epg.this : name => epg.id }
}
