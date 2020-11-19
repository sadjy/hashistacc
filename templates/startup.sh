#!/usr/bin/env bash
set -e

function configConsul() {
  sudo mkdir -p /mnt/consul
  sudo mkdir -p /etc/consul.d
  sudo tee /etc/consul.d/config.json > /dev/null <<EOF
  ${consul_config}
EOF
}

function configNomad() {
  sudo mkdir -p /mnt/nomad
  sudo mkdir -p /etc/nomad.d
  sudo tee /etc/nomad.d/config.hcl > /dev/null <<EOF
  ${nomad_config}
EOF
}

function installCloudwatchNomadMetrics() {
  sudo tee /opt/cloudwatch-nomad-metrics.py > /dev/null <<"EOF"
#!/usr/bin/env python3

import collections
import datetime
import sched
import time
import pprint
import nomad
import boto3

client_cloudwatch = boto3.client('cloudwatch', region_name='${region}')
client_nomad = nomad.Nomad()
summary_status = frozenset(['Queued', 'Starting', 'Running', 'Failed', 'Complete', 'Lost'])

def put_metrics(now):
    jobs = client_nomad.jobs.get_jobs()
    summ = collections.Counter({s: 0 for s in summary_status})
    for j in jobs:
        summ.update(list(j["JobSummary"]["Summary"].values())[0])

    metric_data = [
        {
            'MetricName': 'Job summary',
            'Timestamp': now,
            'Value': count,
            'Unit': 'Count',
            'Dimensions': [
                { 'Name': 'Status', 'Value': status },
            ],
        }
        for status, count in summ.items()
    ]
    pprint.pprint(metric_data)
    client_cloudwatch.put_metric_data(
        Namespace='Nomad',
        MetricData=metric_data,
    )
    enter_next(s, put_metrics)

def enter_next(s, function):
    now = datetime.datetime.utcnow()
    now_next = now.replace() + datetime.timedelta(seconds=5)
    s.enterabs(
        time=now_next.timestamp(),
        priority=1,
        action=function,
        argument=(now_next,),
    )

if __name__ == '__main__':
    s = sched.scheduler(lambda: datetime.datetime.utcnow().timestamp(), time.sleep)
    enter_next(s, put_metrics)
    put_metrics
    while True:
        s.run()
EOF

  sudo tee /etc/systemd/system/cloudwatch-nomad-metrics.service > /dev/null <<"EOF"
[Unit]
Description=Cloudwatch Nomad Metrics
Wants=network-online.target
After=network-online.target
Wants=nomad.service
After=nomad.service

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/bin/bash -c "export NOMAD_TOKEN=$$(export VAULT_ADDR=http://127.0.0.1:8200 && vault kv get -field=value acltoken/bootstrap);/opt/cloudwatch-nomad-metrics.py"
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=60
StartLimitIntervalSec=60
StartLimitBurst=1

[Install]
WantedBy=multi-user.target
EOF

  sudo chmod +x /opt/cloudwatch-nomad-metrics.py
}

function configVault() {
  echo "Creating Vault user..."
  sudo groupadd vault && useradd -r -g vault -d /usr/local/vault -m -s /sbin/nologin -c "Vault user" vault 

  sudo mkdir -p /mnt/vault
  sudo mkdir -p /etc/vault.d
  sudo mkdir -p /etc/vault.d/plugins

  cd /tmp && curl -L -o vault-secrets-gen.tgz https://github.com/sethvargo/vault-secrets-gen/releases/download/v0.0.6/vault-secrets-gen_0.0.6_linux_amd64.tgz
  sudo tar -xzf vault-secrets-gen.tgz && sudo mv vault-secrets-gen /etc/vault.d/plugins/ && sudo chmod +x /etc/vault.d/plugins/vault-secrets-gen 
  sudo setcap cap_ipc_lock=+ep /etc/vault.d/plugins/vault-secrets-gen

  sudo tee /etc/vault.d/vault_${vault_mode}.hcl > /dev/null <<EOF
  ${vault_config}
EOF

  sudo tee /etc/systemd/system/vault.service > /dev/null <<"EOF"
[Unit]
Description=Vault ${vault_mode}
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
RestartSec=42s
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/local/bin/vault ${vault_mode} -config=/etc/vault.d/vault_${vault_mode}.hcl -log-level=debug
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
LimitMEMLOCK=infinity
User=vault
Group=vault

[Install]
WantedBy=multi-user.target
EOF
}

function setSecretsGenPlugin() {
  export SHA256=$(shasum -a 256 "/etc/vault.d/plugins/vault-secrets-gen" | cut -d' ' -f1)
  vault plugin register -sha256="$${SHA256}" -command="vault-secrets-gen" secret secrets-gen
  vault secrets enable -path="gen" -plugin-name="secrets-gen" plugin
}

function createTemplates() {
  touch /tmp/$1
  touch /tmp/$2 
  sudo mkdir -p /mnt/$1/templates
  sudo mkdir -p /mnt/$1/certs
  sudo tee /mnt/$1/templates/agent.crt.tpl > /dev/null <<EOF
{{ with secret "$1-intermediate-pki/issue/$1-cluster" "common_name=$2" "ttl=24h" "alt_names=localhost" "ip_sans=$PUBLIC_IP,127.0.0.1"}}
{{ .Data.certificate }}
{{ end }}
EOF
  sudo tee /mnt/$1/templates/agent.key.tpl > /dev/null <<EOF
{{ with secret "$1-intermediate-pki/issue/$1-cluster" "common_name=$2" "ttl=24h" "alt_names=localhost" "ip_sans=$PUBLIC_IP,127.0.0.1"}}
{{ .Data.private_key }}
{{ end }}
EOF
  sudo tee /mnt/$1/templates/ca.crt.tpl > /dev/null <<EOF
{{ with secret "$1-intermediate-pki/issue/$1-cluster" "common_name=$2" "ttl=24h"}}
{{ .Data.issuing_ca }}
{{ end }}
EOF
  sudo tee /mnt/$1/templates/cli.crt.tpl > /dev/null <<EOF
{{ with secret "$1-intermediate-pki/issue/$1-cluster" "ttl=24h" }}
{{ .Data.certificate }}
{{ end }}
EOF
  sudo tee /mnt/$1/templates/cli.key.tpl > /dev/null <<EOF
{{ with secret "$1-intermediate-pki/issue/$1-cluster" "ttl=24h" }}
{{ .Data.private_key }}
{{ end }}
EOF
}

function setPKI() {
  vault login $(cat /mnt/vault/vault.token)
  vault secrets enable -path=$1-root-pki pki
  vault secrets tune -max-lease-ttl=87600h $1-root-pki
  vault write -field=certificate $1-root-pki/root/generate/internal \
      common_name="$2" ttl=87600h > CA_cert.crt
  vault secrets enable -path=$1-intermediate-pki pki
  vault secrets tune -max-lease-ttl=43800h $1-intermediate-pki
  vault write -format=json $1-intermediate-pki/intermediate/generate/internal \
      common_name="$2 Intermediate Authority" \
      ttl="43800h" | jq -r '.data.csr' > $1-intermediate-pki.csr
  vault write -format=json $1-root-pki/root/sign-intermediate \
      csr=@$1-intermediate-pki.csr format=pem_bundle \
      ttl="43800h" | jq -r '.data.certificate' > $1-intermediate.cert.pem
  vault write $1-intermediate-pki/intermediate/set-signed certificate=@$1-intermediate.cert.pem
  vault write $1-intermediate-pki/roles/$1-cluster allowed_domains=$2 \
      allow_subdomains=true max_ttl=86400s require_cn=false generate_lease=true
  sudo mkdir -p /mnt/vault/policies
  sudo tee /mnt/vault/policies/$1-tls-policy.hcl > /dev/null <<EOF
path "$1-intermediate-pki/issue/$1-cluster" {
  capabilities = ["update"]
}
EOF
  vault policy write $1-tls-policy /mnt/vault/policies/$1-tls-policy.hcl
}

function configureAppRoleEngineVault() {
  vault write auth/approle/role/$1 token_num_uses=10 token_ttl=20m token_max_ttl=30m token_policies=$4
  vault write auth/approle/role/$1/role-id role_id=$2
  vault write auth/approle/role/$1/custom-secret-id secret_id=$3
}

function setNomadVaultIntegration() {
  sudo curl https://nomadproject.io/data/vault/nomad-server-policy.hcl -sLo /mnt/vault/policies/nomad-server-policy.hcl
  sudo curl https://nomadproject.io/data/vault/nomad-cluster-role.json -sLo /mnt/vault/policies/nomad-cluster-role.json
  sudo tee -a /mnt/vault/policies/nomad-server-policy.hcl > /dev/null <<"EOF"
path "acltoken/*"
{
  capabilities = ["create", "read", "update"]
}
EOF
  vault policy write nomad-server /mnt/vault/policies/nomad-server-policy.hcl
  vault write /auth/token/roles/nomad-cluster @/mnt/vault/policies/nomad-cluster-role.json
  sudo tee /mnt/vault/policies/nomad-cluster.hcl > /dev/null <<"EOF"
path "secret/*"
{
  capabilities = ["read"]
}

path "gen/password"
{
  capabilities = ["update"]
}
EOF
  vault policy write nomad-cluster /mnt/vault/policies/nomad-cluster.hcl
  vault write auth/approle/role/nomad-server token_policies="nomad-tls-policy,consul-tls-policy,nomad-server"
}

echo "Grabbing IPs..."
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

if [[  ${consul_mode} != "disabled" ]]; then
  configConsul
  createTemplates "consul" "${consul_mode}.service.consul"
  if [[ ${consul_mode} == "server" ]]; then
    sudo tee /mnt/consul/refreshtoken.sh > /dev/null <<"EOF"
jq --arg token $(sudo cat /etc/vault.d/sink) '.connect.ca_config.token = $token' /etc/consul.d/config.json > /tmp/tmp.json && mv /tmp/tmp.json /etc/consul.d/config.json
EOF
    sudo chmod +x /mnt/consul/refreshtoken.sh
    (sudo crontab -l 2>/dev/null; echo "*/5 * * * * /mnt/consul/refreshtoken.sh") | sudo crontab -
  fi
fi

if [[  ${nomad_mode} != "disabled" ]]; then
  configNomad
  createTemplates "nomad" "${nomad_mode}.global.nomad"
  if [[ ${nomad_mode} == "server" ]]; then
    installCloudwatchNomadMetrics  
  fi
fi

if [[  ${vault_mode} != "disabled" ]]; then
  configVault
  if [[ ${vault_mode} == "agent" ]]; then
    if [[ ${consul_mode} == "server" ]]; then
      echo "${approles.consul.role_id}" > /mnt/vault/role_id
      echo "${approles.consul.secret_id}" > /mnt/vault/secret_id
    elif [[ ${nomad_mode} == "server" ]]; then
      echo "${approles.nomad_server.role_id}" > /mnt/vault/role_id
      echo "${approles.nomad_server.secret_id}" > /mnt/vault/secret_id
    else
      echo "${approles.nomad_cluster.role_id}" > /mnt/vault/role_id
      echo "${approles.nomad_cluster.secret_id}" > /mnt/vault/secret_id
    fi
    sudo chown vault:root /mnt/consul/certs
    if [[ ${nomad_mode} != "disabled" ]]; then
      sudo chown vault:root /mnt/nomad/certs
    fi
  fi
fi

echo "Starting services..."

sudo systemctl daemon-reload
  
if [[  ${vault_mode} != "disabled" ]]; then
  sudo chown -R vault:vault /etc/vault.d
  sudo chmod -R 0755 /etc/vault.d/
  sudo chown -R vault:vault /mnt/vault
  sudo chmod -R 0755 /mnt/vault
  sudo systemctl enable vault.service
  if [[ ${vault_mode} == "server" ]]; then
    sudo systemctl start vault.service
    sleep 10
    export VAULT_ADDR=http://127.0.0.1:8200
    vault operator init -recovery-shares=1 -recovery-threshold=1 | grep Token | cut -d' ' -f 4 | sudo tee /mnt/vault/vault.token
    vault login $(cat /mnt/vault/vault.token)
    vault auth enable approle
    setPKI "nomad" "global.nomad"
    setPKI "consul" "service.consul"
    configureAppRoleEngineVault "nomad-server" "${approles.nomad_server.role_id}" "${approles.nomad_server.secret_id}" "consul-tls-policy,nomad-tls-policy"
    configureAppRoleEngineVault "nomad-cluster" "${approles.nomad_cluster.role_id}" "${approles.nomad_cluster.secret_id}" "consul-tls-policy,nomad-tls-policy"
    configureAppRoleEngineVault "consul" "${approles.consul.role_id}" "${approles.consul.role_id}" "consul-tls-policy"
    setSecretsGenPlugin
    setNomadVaultIntegration
    vault secrets enable -version=2 -path=secret kv
    vault secrets enable -version=2 -path=acltoken kv
  else
    sleep 30
    sudo systemctl start vault.service
    export VAULT_TOKEN=$(cat /etc/vault.d/sink)
  fi
fi

if [[  ${consul_mode} != "disabled" ]]; then
  sleep 30
#  sudo /mnt/consul/refreshtoken.sh
  sudo systemctl enable consul.service
  sudo systemctl start consul.service
  if [[ ${consul_mode} == "server" ]]; then
    sleep 10
    curl http://127.0.0.1:8500/v1/query \
      --request POST \
      --data \
'{
  "Name": "",
  "Template": {
    "Type": "name_prefix_match"
  },
  "Service": {
    "Service": "$${name.full}",
    "Failover": {
      "NearestN": 2
    }
  }
}'
  fi  
fi

if [[  ${nomad_mode} != "disabled" ]]; then
  sudo systemctl enable nomad.service
  sudo systemctl start nomad.service
  if [[ ${nomad_mode} == "server" ]]; then
    sudo systemctl enable cloudwatch-nomad-metrics.service
    sudo systemctl start cloudwatch-nomad-metrics.service
    sleep 80
    ACL_TOKEN=$(nomad acl bootstrap | grep "Secret" | tr -s ' ' | cut -d' ' -f 4 | sudo tee /mnt/nomad/acl.token)
    if [[ ! -z "$ACL_TOKEN" ]]; then export VAULT_ADDR=http://127.0.0.1:8200 && vault kv put acltoken/bootstrap value="$ACL_TOKEN"; fi
  else
    sudo systemctl enable autoshutdown.service
    sudo systemctl start autoshutdown.service
  fi
fi