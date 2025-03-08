resource "hcloud_ssh_key" "jesse" {
  name       = "jesse"
  public_key = file("/home/jessew/.ssh/id_ed25519.pub")
}
