locals {
  # Mail server, and target of the Minecraft SRV record
  mail_host = "${hcloud_server.servers["faithplate"].name}.infra.cpluspatch.com"
}

# Minecraft records
resource "cloudflare_dns_record" "cpluscraft_srv" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "SRV record for cpluscraft"
  name    = "_minecraft._tcp.mc.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_minecraft"
    proto    = "_tcp"
    name     = "mc.cpluspatch.com."
    priority = 5
    weight   = 0
    port     = 25565
    target   = "${local.mail_host}."
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
  content  = local.mail_host
  ttl      = 1
}

resource "cloudflare_dns_record" "email_spf" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "SPF record for cpluspatch.com"
  name    = "cpluspatch.com"
  type    = "TXT"
  content = "\"v=spf1 a:${local.mail_host} -all\""
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
resource "cloudflare_dns_record" "email_autodiscover" {
  for_each = {
    submission  = 587
    submissions = 465
    imap        = 143
    imaps       = 993
  }

  zone_id = var.cpluspatch-com-zone_id
  comment = "Used for email client autodiscover"
  name    = "_${each.key}._tcp.cpluspatch.com"
  type    = "SRV"
  data = {
    service  = "_${each.key}"
    proto    = "_tcp"
    name     = "cpluspatch.com."
    priority = 5
    weight   = 0
    port     = each.value
    target   = "${local.mail_host}."
  }
  ttl = 3600
}

# Additional records will be CNAMEs to main servers
resource "cloudflare_dns_record" "infra_ipv4" {
  for_each = { for name, server in hcloud_server.servers : name => server if local.servers[name].ipv4 }

  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv4 record for the ${each.key} server"
  name    = "${each.key}.infra.cpluspatch.com"
  type    = "A"
  content = each.value.ipv4_address
  ttl     = 1
}

resource "cloudflare_dns_record" "infra_ipv6" {
  for_each = hcloud_server.servers

  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv6 record for the ${each.key} server"
  name    = "${each.key}.infra.cpluspatch.com"
  type    = "AAAA"
  content = each.value.ipv6_address
  ttl     = 1
}

# Reverse DNS records
resource "hcloud_rdns" "infra_ip_rdns" {
  for_each = { for name, server in hcloud_server.servers : name => server if local.servers[name].ipv4 }

  ip_address = each.value.ipv4_address
  server_id  = each.value.id
  dns_ptr    = "${each.key}.infra.cpluspatch.com"
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
