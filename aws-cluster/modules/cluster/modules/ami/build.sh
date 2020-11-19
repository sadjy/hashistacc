#!/bin/bash

tee /tmp/packer-config.json > /dev/null <<EOF
  ${packer_config}
EOF

AMI_ID=$(packer build /tmp/packer-config.json | grep ${region} | grep ami- | cut -d ' ' -f 2)
jq -n --arg id "$AMI_ID" '{"ami_id":$id}'