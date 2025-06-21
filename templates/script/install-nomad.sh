#!/bin/bash
# This is a cloud-init template file. Bash "dollar-brace" variables should be double-dollar escaped `$$`.
set -e

mkdir -p '/tmp/nomad'
mkdir -p '/usr/local/bin'
# The variables in the URL come from cloud-init, not Bash, so the URL can be single-quoted.
curl -fsSL 'https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip' -o '/tmp/nomad/nomad.zip'
unzip -o '/tmp/nomad/nomad.zip' -d '/tmp/nomad'
mv '/tmp/nomad/nomad' '/usr/local/bin/nomad'
chmod +x '/usr/local/bin/nomad'
rm -rf '/tmp/nomad'
