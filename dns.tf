# Additional records will be CNAMEs to main servers
resource "cloudflare_dns_record" "chell_infra_ipv4" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv4 record for the ${local.chell.server.name} server"
  name    = "chell.infra.cpluspatch.com"
  type    = "A"
  content = local.chell.ipv4.ip_address
  ttl     = 1
}

resource "cloudflare_dns_record" "chell_infra_ipv6" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv6 record for the ${local.chell.server.name} server"
  name    = "chell.infra.cpluspatch.com"
  type    = "AAAA"
  content = local.chell.ipv6.ip_address
  ttl     = 1
}

# Create CNAME records for each server
# In the above example, we should have:
# CNAME matrix.cpluspatch.dev -> chell.infra.cpluspatch.com
# CNAME uptime.cpluspatch.com -> chell.infra.cpluspatch.com
# etc
resource "cloudflare_dns_record" "server_cnames" {
  for_each = toset(local.chell.domains)

  zone_id = var.cpluspatch-com-zone_id
  name    = each.key
  type    = "CNAME"
  content = "chell.infra.cpluspatch.com"
  ttl     = 1
}
