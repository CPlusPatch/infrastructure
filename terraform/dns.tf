# Additional records will be CNAMEs to main servers
resource "cloudflare_dns_record" "infra_ipv4" {
  # Local.servers is an array of objects
  # So it must be transformed before it can be used as a for_each
  for_each = tomap({ for s in local.servers : s.server.name => s })

  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv4 record for the ${each.value.server.name} server"
  name    = "${each.value.server.name}.infra.cpluspatch.com"
  type    = "A"
  content = each.value.server.ipv4_address
  ttl     = 1
}

resource "cloudflare_dns_record" "infra_ipv6" {
  for_each = tomap({ for s in local.servers : s.server.name => s })

  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv6 record for the ${each.value.server.name} server"
  name    = "${each.value.server.name}.infra.cpluspatch.com"
  type    = "AAAA"
  content = each.value.server.ipv6_address
  ttl     = 1
}

# Create CNAME records for each server's configured domains
resource "cloudflare_dns_record" "server_cnames" {
  for_each = local.final_domains

  zone_id = each.value.zone
  comment = "CNAME record for ${each.key}"
  name    = each.key
  type    = "CNAME"
  content = "${each.value.name}.infra.cpluspatch.com"
  ttl     = 1
}
