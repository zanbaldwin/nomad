#!/bin/bash
set -e

mkdir -p "/tmp/nomad"
mkdir -p "/usr/local/bin"
curl -fsSL "https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip" -o "/tmp/nomad/nomad.zip"
unzip -o "/tmp/nomad/nomad.zip" -d "/tmp/nomad"
mv "/tmp/nomad/nomad" "/usr/local/bin/nomad"
chmod +x "/usr/local/bin/nomad"
rm -rf "/tmp/nomad"
