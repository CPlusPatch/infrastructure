variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API Token"
}

variable "cloudflare_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "cpluspatch-com-zone_id" {
  type        = string
  description = "Cloudflare Zone ID for cpluspatch.com"
  nullable    = false
}

variable "cpluspatch-dev-zone_id" {
  type        = string
  description = "Cloudflare Zone ID for cpluspatch.dev"
  nullable    = false
}

variable "pissing-nexus-zone_id" {
  type        = string
  description = "Cloudflare Zone ID for pissing.nexus"
  nullable    = false
}

variable "nixos_vars_file" {
  type        = string
  description = "Path to the NixOS vars file that will be generated"
  default     = "nixos-vars.json"
}

variable "sops_file" {
  type        = string
  description = "Path to the SOPS secrets file containing the age key, relative to the module root"
  default     = "../secrets/age.yaml"
}
