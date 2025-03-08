# Converts a Hetzner server to NixOS using NixOS-infect
# Stolen from https://guillaumebogard.dev/posts/declarative-server-management-with-nix/ xoxo

variable "ssh_user" {
  type        = string
  description = "SSH user to connect to the target host"
}

variable "target_host" {
  type        = string
  description = "Host to convert to NixOS (e.g. IP address or domain)"
}

resource "null_resource" "nixos_install" {
  connection {
    type = "ssh"
    user = var.ssh_user
    host = var.target_host
  }

  provisioner "remote-exec" {
    inline = [
      "curl https://raw.githubusercontent.com/elitak/NixOS-infect/master/NixOS-infect | PROVIDER=hetznercloud Nix_CHANNEL=NixOS-24.11 bash 2>&1 | tee /tmp/infect.log",
    ]
  }
}
