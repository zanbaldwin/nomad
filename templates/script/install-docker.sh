#!/bin/bash
# This file is included as-is, and does not pass through templating: do NOT escape `${}` variables.
set -e

apt-get update
apt-get install -y \
    'apt-transport-https' \
    'ca-certificates' \
    'curl' \
    'gnupg' \
    'lsb-release'

install -m 0755 -d '/etc/apt/keyrings'
curl -fsSL 'https://download.docker.com/linux/ubuntu/gpg' -o '/etc/apt/keyrings/docker.asc'
chmod 'a+r' '/etc/apt/keyrings/docker.asc'

. '/etc/os-release'
export RELEASE="${UBUNTU_CODENAME:-${VERSION_CODENAME:-$(lsb_release -cs)}}"
# Add the repository to Apt sources:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${RELEASE} stable" \
    | tee '/etc/apt/sources.list.d/docker.list' >'/dev/null'

apt-get update
apt-get install -y \
    'docker-ce' \
    'docker-ce-cli' \
    'containerd.io' \
    'docker-buildx-plugin' \
    'docker-compose-plugin'
