#!/bin/bash

# Script Name: install-ha-setup.sh
# Description: Automates the creation of a HashiCorp Vault High-Availability (HA) cluster.
#               This script provisions the necessary resources, configures Vault nodes,
#               sets up backend storage (e.g., Consul), and ensures HA failover readiness.
# Last Updated: 2024-11-26
# Created By: Daniel Mandelblat (daniel.mandelblat1@hp.com)

set -e

# Changeable variables
namespace="vault"
ingress_url="http://vault.my.domain/"

# Execute command and console it
function execute(){
        cmd="$*"
        echo "Executing: $cmd"
        eval $cmd
}

# Unseal the Vault server
function unseal(){
        index=$1
        cat cluster-keys.json  | jq -r '.unseal_keys_b64[]'  | while read line
        do
                execute "kubectl exec -n ${namespace} vault-${index} -- vault operator unseal ${line}"
        done
}

# Print welcome banner
echo "Vault HA mode setup is begin..."

# Deploy the Helm Charr
helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/vault
helm install vault hashicorp/vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true'

# Wait to the pod be up
while true
do
        pod_status=$(kubectl -n $namespace get po vault-0 -ojson | jq -r '.status.containerStatuses[0].started')
        if [[ $pod_status == true ]]
        then
                echo "Vault pod is running, please wait for the next step..."
                break
        else
                echo "Waiting to the pod to be running, current state: $pod_status"
                sleep 1
        fi
done

# Init the cluster
kubectl exec vault-0 -n $namespace -- vault operator init \
        -format=json > cluster-keys.json
cat cluster-keys.json

# Unseal first pod [0]
unseal 0

# Join others Vault peers & Unseal them
for i in 1 2
do
        # Join
        execute "kubectl exec -n ${namespace} vault-${i} -- vault operator raft join http://vault-0.vault-internal:8200"

        # Unseal
        unseal $i
done

# Get the token
token="$(cat cluster-keys.json | jq -r '.root_token')"

# Login and check the cluster state
execute "kubectl exec -ti vault-0 -- vault login ${token}"
execute "kubectl exec -ti vault-0 -- vault operator raft list-peers"

# Print token
echo "====== Process has been finished ======"
echo "Please login to UI [ $ingress_url ] with this token: $token"
