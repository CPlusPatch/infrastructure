# Minecraft records
resource "cloudflare_dns_record" "camaradcraft_srv" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "SRV record for camaradcraft"
  name    = "_minecraft._tcp.camaradcraft.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_minecraft"
    proto    = "_tcp"
    name     = "camaradcraft.cpluspatch.com."
    priority = 5
    weight   = 0
    port     = 25565
    target   = "${hcloud_server.faithplate.name}.infra.cpluspatch.com."
  }
  ttl = 1
}

# Email records
resource "cloudflare_dns_record" "email_mx" {
  zone_id  = var.cpluspatch-com-zone_id
  comment  = "MX record for cpluspatch.com"
  name     = "cpluspatch.com"
  type     = "MX"
  priority = 10
  content  = "${hcloud_server.faithplate.name}.infra.cpluspatch.com"
  ttl      = 1
}

resource "cloudflare_dns_record" "email_spf" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "SPF record for cpluspatch.com"
  name    = "cpluspatch.com"
  type    = "TXT"
  content = "\"v=spf1 a:${hcloud_server.faithplate.name}.infra.cpluspatch.com -all\""
  ttl     = 10800
}

resource "cloudflare_dns_record" "email_dmarc" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "DMARC record for cpluspatch.com"
  name    = "_dmarc.cpluspatch.com"
  type    = "TXT"
  content = "\"v=DMARC1; p=reject; rua=mailto:dmarc-reports@cpluspatch.com; ruf=mailto:dmarc-reports@cpluspatch.com; fo=1; ri=86400;\""
  ttl     = 10800
}

resource "cloudflare_dns_record" "email_dkim" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "DKIM record for cpluspatch.com"
  name    = "mail._domainkey.cpluspatch.com"
  type    = "TXT"
  content = "\"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDXwL4re4GT78duA4Nfjo/GZ69GCrH4z0fDZFmQNUpoQvVIst4TNkltLh11XlgpvIKU1mn0dRTiqoMloyhfnlOtawNdjS78B5Pb6XzBjLbWvn8rds84Jt5ruvj1o4XD6ADK4yfc9mpLT1e0pu5gMRhuYrxAGeK1y7+P4N6jfZgFAwIDAQAB\""
  ttl     = 10800
}

# Email autodiscover records
resource "cloudflare_dns_record" "email_autodiscover_submission" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Used for email client autodiscover"
  name    = "_submission._tcp.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_submission"
    proto    = "_tcp"
    name     = "cpluspatch.com."
    priority = 5
    weight   = 0
    port     = 587
    target   = "${hcloud_server.faithplate.name}.infra.cpluspatch.com."
  }
  ttl = 3600
}

resource "cloudflare_dns_record" "email_autodiscover_submissions" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Used for email client autodiscover"
  name    = "_submissions._tcp.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_submissions"
    proto    = "_tcp"
    name     = "cpluspatch.com."
    priority = 5
    weight   = 0
    port     = 465
    target   = "${hcloud_server.faithplate.name}.infra.cpluspatch.com."
  }
  ttl = 3600
}
resource "cloudflare_dns_record" "email_autodiscover_imap" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Used for email client autodiscover"
  name    = "_imap._tcp.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_imap"
    proto    = "_tcp"
    name     = "cpluspatch.com."
    priority = 5
    weight   = 0
    port     = 143
    target   = "${hcloud_server.faithplate.name}.infra.cpluspatch.com."
  }
  ttl = 3600
}

resource "cloudflare_dns_record" "email_autodiscover_imaps" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Used for email client autodiscover"
  name    = "_imaps._tcp.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_imaps"
    proto    = "_tcp"
    name     = "cpluspatch.com."
    priority = 5
    weight   = 0
    port     = 993
    target   = "${hcloud_server.faithplate.name}.infra.cpluspatch.com."
  }
  ttl = 3600
}

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

# Reverse DNS records
resource "hcloud_rdns" "infra_ip_rdns" {
  for_each = tomap({ for s in local.servers : s.server.name => s })

  ip_address = each.value.server.ipv4_address
  server_id  = each.value.server.id
  dns_ptr    = "${each.value.server.name}.infra.cpluspatch.com"
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
