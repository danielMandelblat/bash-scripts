#!/bin/bash

###############################################################################
# Script Name: cleanup-unused-ipaddresses.sh
# Description: 
#   This script identifies and prints commands to delete unused IP addresses 
#   from Metal3 IPAM in a Kubernetes cluster. It compares the list of allocated
#   IPs against the actual node IPs and skips the VIP used by the API server.
#
# Author: Daniel Mandelblat
# Date: 2025-08-03
###############################################################################

# Get the API server's VIP (without port)
vip=$(kubectl get kubeadmconfig -A -o json \
  | jq -r '[.items[] | {endpoint: .spec.joinConfiguration.discovery.bootstrapToken.apiServerEndpoint, timestamp: .metadata.creationTimestamp}] 
  | sort_by(.timestamp) 
  | last 
  | .endpoint' \
  | awk -F ":" '{print $1}'
)


# Get all IP addresses from IPAM
readarray -t ipaddress < <(
    kubectl get ipaddresses.ipam.metal3.io -A -o json \
    | jq -r '.items[].spec.address'
)

# Get all node IPs from Calico annotations (without CIDR)
nodes_ips=($(
    kubectl get node -o json \
    | jq -r '.items[].metadata.annotations["projectcalico.org/IPv4Address"]' \
    | awk -F "/" '{print $1}'
))

# Loop through IP addresses from IPAM
for ip in "${ipaddress[@]}"; do
    # Skip the API server VIP
    if [[ "$vip" == "$ip" ]]; then
        continue
    fi

    exist="false"
    for node_ip in "${nodes_ips[@]}"; do
        if [[ "$ip" == "$node_ip" ]]; then
            exist="true"
            break
        fi
    done

    if [[ "$exist" == "false" ]]; then
        # Fetch full IP object details
        ipaddress_object="$(kubectl get ipaddresses.ipam.metal3.io -A -o json \
            | jq -r --arg ip "$ip" '.items[] | select(.spec.address == $ip)')"
        ipaddress_name="$(echo "$ipaddress_object" | jq -r '.metadata.name')"
        ipaddress_namespace="$(echo "$ipaddress_object" | jq -r '.metadata.namespace')"

        # Print the delete command
        echo "kubectl delete ipaddresses.ipam.metal3.io -n $ipaddress_namespace $ipaddress_name"
    fi
done

# Delete all capv-x pods
kubectl get po -A | grep cap | while read line; do kubectl delete po -n $(echo $line | awk '{print $1}') $(echo $line | awk '{print $2}'); done




