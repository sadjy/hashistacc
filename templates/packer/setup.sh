#!/usr/bin/env bash
set -e


function installDependencies() {
	echo "Installing dependencies..."
	sudo apt-get -qq update &>/dev/null
	sudo apt-get -yqq install unzip jq &>/dev/null
	sudo sed -i '1 i\nameserver 127.0.0.1' /etc/resolv.conf

	echo "Installing Docker..."
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh get-docker.sh
}

function installStack() {
  sudo curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt update
  sudo apt install consul nomad vault -y

}

function setServices() {
  sudo tee /etc/systemd/system/consul.service > /dev/null <<"EOF"
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target
Wants=vault.service
After=vault.service

[Service]
Restart=on-failure
Environment=CONSUL_ALLOW_PRIVILEGED_PORTS=true
ExecStart=/usr/local/bin/consul agent -config-dir="/etc/consul.d" -dns-port="53" -recursor="172.31.0.2"
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

  sudo tee /etc/systemd/system/nomad.service > /dev/null <<"EOF"
[Unit]
Description=Nomad
Wants=network-online.target
After=network-online.target
Wants=consul.service
After=consul.service
Wants=vault.service
After=vault.service

[Service]
Environment="VAULT_TOKEN=$(cat /etc/vault.d/sink)"
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitIntervalSec=10
StartLimitBurst=3
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
}

function installAutoShutdown() {
  echo "Setting up auto shutdown script"
  sudo tee /opt/autoshutdown.py > /dev/null <<"EOF"
#!/usr/bin/env python3

import collections
import datetime
import sched
import time
import subprocess
import nomad

client_nomad = nomad.Nomad(secure=True, cert=("/mnt/nomad/certs/agent.crt", "/mnt/nomad/certs/agent.key"))
counter = 0

def check_jobs(now):
    global counter
    jobs = client_nomad.jobs.get_jobs()
    nodes = client_nomad.nodes.get_nodes()
    job_count = 0
    ready_nodes = 0
    for j in jobs:
        if j["Type"] == "service":
            job_count += list(j["JobSummary"]["Summary"].values())[0]["Running"]
    if job_count == 0:
        counter += 1
    else:
      counter = 0

    for node in nodes:
      if node["Status"] == "ready":
         ready_nodes += 1

    if counter == 60 and ready_nodes > 2:
        print("No jobs running for a while... Shutting down")
        subprocess.call(["shutdown", "-h", "now"])
    enter_next(s, check_jobs)

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
    enter_next(s, check_jobs)
    check_jobs
    while True:
        s.run()
EOF

  sudo tee /etc/systemd/system/autoshutdown.service > /dev/null <<"EOF"
[Unit]
Description=Housekeeping
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/opt/autoshutdown.py
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitIntervalSec=10
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

  sudo chmod +x /opt/autoshutdown.py  
}

function main() {
    installDependencies
    installStack
    setServices
    installAutoShutdown
}

main