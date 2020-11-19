pid_file = "/etc/vault.d/.pidfile"

vault {
        address = "${vault_lb}"
}

auto_auth {
  method {
    type = "approle"

    config = {
      role_id_file_path = "/mnt/vault/role_id"
      secret_id_file_path = "/mnt/vault/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"

    config = {
      path = "/etc/vault.d/sink"
    }
  }
}

cache {
        use_auto_auth_token = true
}

listener "tcp" {
   address = "127.0.0.1:8200"
   tls_disable = true
}
%{ if nomad_mode != "disabled" }
template {
  source      = "/mnt/nomad/templates/agent.crt.tpl"
  destination = "/mnt/nomad/certs/agent.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/nomad/templates/agent.key.tpl"
  destination = "/mnt/nomad/certs/agent.key"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/nomad/templates/ca.crt.tpl"
  destination = "/mnt/nomad/certs/ca.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/nomad/templates/cli.crt.tpl"
  destination = "/mnt/nomad/certs/cli.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/nomad/templates/cli.key.tpl"
  destination = "/mnt/nomad/certs/cli.key"
  wait {
    min = "5s"
    max = "10s"
  }
}
%{ endif }

template {
  source      = "/mnt/consul/templates/agent.crt.tpl"
  destination = "/mnt/consul/certs/agent.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}

%{ if consul_mode == "server" }
template {
  source      = "/mnt/consul/templates/agent.key.tpl"
  destination = "/mnt/consul/certs/agent.key"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/consul/templates/ca.crt.tpl"
  destination = "/mnt/consul/certs/ca.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/consul/templates/cli.crt.tpl"
  destination = "/mnt/consul/certs/cli.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}

template {
  source      = "/mnt/consul/templates/cli.key.tpl"
  destination = "/mnt/consul/certs/cli.key"
  wait {
    min = "5s"
    max = "10s"
  }
}
%{ endif }

%{ if consul_mode == "client" }
template {
  source      = "/mnt/consul/templates/ca.crt.tpl"
  destination = "/mnt/consul/certs/ca.crt"
  wait {
    min = "5s"
    max = "10s"
  }
}
%{ endif }

