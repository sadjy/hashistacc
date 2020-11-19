listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_address  = "$PUBLIC_IP:8201"
  tls_disable      = "true"
}

storage "file" {
  path = "/mnt/vault/data"
}

api_addr = "http://$PUBLIC_IP:8200"
cluster_addr = "https://$PUBLIC_IP:8201"
ui = true
plugin_directory = "/etc/vault.d/plugins"

seal "awskms" {
  region = "${region}"
  kms_key_id = "${kms_key}"
}

