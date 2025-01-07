#!/bin/bash

# Description: This BASH script automates the configuration of Docker to work with an insecure private registry and adds a custom CA (Certificate Authority) certificate to the system's trusted certificates
# Writer: Daniel Mandelblat (danielmande@gmail.com)
# Date: 07/01/2024

export docker-registry-server="my-server-url:5000"
sudo apt-get install -y ca-certificates
cat <<EOF > /etc/docker/daemon.json
{
    "insecure-registries" : [ "$docker-registry-server" ]
}
EOF
cat <<EOF > /usr/local/share/ca-certificates/HPIncChain.crt
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
EOF
sudo update-ca-certificates
sudo systemctl restart docker.service
