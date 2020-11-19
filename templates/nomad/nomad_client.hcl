data_dir   = "/mnt/nomad"
datacenter = "${datacenter}"
region = "${region}"
bind_addr = "0.0.0.0"
client {
  enabled = true
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics = true
}

tls {
  http = false
  rpc  = true

  ca_file   = "/mnt/nomad/certs/ca.crt"
  cert_file = "/mnt/nomad/certs/agent.crt"
  key_file  = "/mnt/nomad/certs/agent.key"

  verify_server_hostname = true
  verify_https_client    = false
}

vault {
  enabled     = true
  address     = "http://127.0.0.1:8200"
}

acl {
  enabled = true
}