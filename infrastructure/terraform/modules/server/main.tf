# modules/server/main.tf

resource "hcloud_ssh_key" "this" {
  name       = "${var.name}-key"
  public_key = var.ssh_public_key
}

resource "hcloud_server" "this" {
  name        = var.name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"

  ssh_keys = [hcloud_ssh_key.this.id]

  firewall_ids = [var.firewall_id]

  # Why: cloud-init runs once at first boot — perfect for "install k3s" later
  user_data = var.user_data != "" ? var.user_data : null

  labels = {
    project = "cloud-native-ai-platform"
    env     = "hobby"
  }
}

# TODO: decide whether the SSH key should live in this module or the root env.
# Hint: if you reuse one key across many servers, move hcloud_ssh_key up to hobby/.