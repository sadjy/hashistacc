# Multi-AZ and Multi-Regions Hashicorp Stack (Consul/Nomad/Vault) on AWS

Basic features:
- Multi-AZ (cycling) and Single Region Nomad + Consul cluster (Consul Servers + Nomad Servers + Nomad Clients)
- Static numbers of servers. ASG groups for every "type" of server with min = max
- Automatic federation of Consul cluster via EC2 tags
- Load balancers for every "server type" + fabio


# Recent improvements
- Multi-regions capability with WAN automatic peering
- Automatic scale-out of Nomad clients when resources (arbitrary) are full using a [custom cloudwatch metrics exporter](https://gitlab.com/sadjy/cloudwatch-nomad-summary-metrics) 
- Vault Servers to the stack + its load balancer (Vault is using Consul storage)
- Auto-unseal of Vault cluster with AWS KMS
- Automatic scale-down of Nomad clients after a period (arbitrary) of unallocated job
- Cloudfare DNS records generation for LB endpoints
- mTLS within the Consul cluster using Vault PKI capabilities
- mTLS within the Nomad cluster (servers + clients) using Vault PKI capabilities
- Every node now runs an Vault Agent (to communicating with the Vault CA) leveraging Auto-Auth
- Enabled Consul Connect for service-mesh
- Automated Nomad ACL token generation and storage in Vault
- Automated scale-in of Nomad clients when they stay idle (without running jobs) for a designated period


# How to use
First please refer to [this repository](https://gitlab.com/sadjy/packer-hashistacc-ami) in order to build the AMI required for this project.

First make sure you fill up the following environment variables to feed the AWS and Cloudflare providers:
AWS:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
Cloudflare:
- `CLOUDFLARE_EMAIL`
- `CLOUDFLARE_API_KEY` / `CLOUDFLARE_API_TOKEN`

After cloning, feel free to change the AWS regions you wish to operate in `./main.tf` as well as the name conventions for the datacenters. Make sure to add your domain (Cloudflare zone) in `./variables.tf` as well as the name of your SSH keypair. 

This project is a WIP.