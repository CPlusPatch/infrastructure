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
