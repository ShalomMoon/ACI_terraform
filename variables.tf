variable "aci_url" {
  description = "APIC URL, for example https://apic.example.com. Prefer TF_VAR_aci_url."
  type        = string
}

variable "aci_username" {
  description = "APIC username. Prefer a dedicated least-privilege automation account."
  type        = string
  sensitive   = true
}

variable "aci_password" {
  description = "APIC password. Supply through TF_VAR_aci_password; never commit it."
  type        = string
  sensitive   = true
}

variable "aci_insecure" {
  description = "Disable APIC TLS certificate verification. Set false when trusted certificates are installed."
  type        = bool
  default     = true
}

variable "configuration_file" {
  description = "Path to the declarative ACI YAML data file."
  type        = string
  default     = "data/aci.yaml"
}
