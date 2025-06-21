#!/bin/bash
# This is a cloud-init template file. Bash "dollar-brace" variables should be double-dollar escaped `$$`.
set -e

mkdir -p '/tmp/consul'
mkdir -p '/usr/local/bin'
# The variables in the URL come from cloud-init, not Bash, so the URL can be single-quoted.
curl -fsSL 'https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip' -o '/tmp/consul/consul.zip'
unzip -o '/tmp/consul/consul.zip' -d '/tmp/consul'
mv '/tmp/consul/consul' '/usr/local/bin/consul'
chmod +x '/usr/local/bin/consul'
rm -rf '/tmp/consul'
