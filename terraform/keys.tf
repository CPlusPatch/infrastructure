# Download SSH public key from https://github.com/CPlusPatch.keys
data "http" "cpluspatch_keys" {
  url = "https://github.com/CPlusPatch.keys"
}

resource "hcloud_ssh_key" "jesse" {
  name       = "jesse"
  public_key = data.http.cpluspatch_keys.response_body
}
