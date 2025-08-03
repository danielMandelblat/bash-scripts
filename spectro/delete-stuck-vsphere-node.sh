#!/bin/bash

###############################################################################
# Author: Daniel Mandelblat
# Date: 2025-08-03
# Description:
# This script gracefully deletes a Kubernetes node and its related resources,
# including Machine, VSphereMachine, IPClaim, and IPAddress objects.
# It also restarts all CAPV-related pods after deletion.
###############################################################################

set -e

# Configurable Variables
###############################################################################
timeout=60        # Timeout (in seconds) for each command
safe=false        # If true, prevents actual execution of commands
force=false       # If true, skips node existence check
###############################################################################

# Validate input
if [ -z "$1" ]; then
  echo "❌ Node name is needed as the first argument."
  exit 1
fi
node_name="$1"

# Logging helper
console() {
  echo "Debug | $*"
}

# Execute command with timeout and error handling
run_cmd() {
  cmd="$*"
  console "Executing command: $cmd"

  if [[ $safe != "true" ]]; then
    if timeout $timeout bash -c "$cmd"; then
      echo "✅ Command completed successfully"
    else
      echo "⏰ Command timeout reached"
    fi
  fi
}

# Check if Kubernetes object exists
# Arguments: <type> <name> [namespace]
check_object() {
  local object_type=$1
  local object_name=$2
  local namespace=$3

  if [[ -z "$namespace" ]]; then
    namespace_flag="-A"
  else
    namespace_flag="-n $namespace"
  fi

  result=$(kubectl get "$object_type" -o json $namespace_flag | jq -r --arg object_name "$object_name" '
    select(.items[].metadata.name == $object_name)' | jq 'length')

  [[ $result -gt 0 ]]
}

# Drain and delete node
drain="kubectl drain $node_name --ignore-daemonsets --delete-emptydir-data"
delete_node="kubectl delete node $node_name --force"

# Retrieve node-related objects
machine_object="$(kubectl get machine -A -ojson | jq -r --arg node_name "$node_name" \
  '.items[] | select(.status.nodeRef.name == $node_name)')"
machine_name="$(echo "$machine_object" | jq -r '.metadata.name')"
machine_namespace="$(echo "$machine_object" | jq -r '.metadata.namespace')"

vspheremachine_object="$(kubectl get vspheremachine -A -ojson | jq -r --arg node_name "$node_name" \
  '.items[] | select(.status.addresses[].address == $node_name)')"
vspheremachine_name="$(echo "$vspheremachine_object" | jq -r '.metadata.name')"
vspheremachine_namespace="$(echo "$vspheremachine_object" | jq -r '.metadata.namespace')"

# IP-related variables
ipclaim=""
ipclaim_name=""
ipclaim_namespace=""
ipcaddress=""
ipcaddress_name=""
ipcaddress_namespace=""

# Check existence functions
check_node() {
  check_object "node" "$node_name"
}

check_machine() {
  check_object "machine" "$machine_name" "$machine_namespace"
}

check_vspheremachine() {
  vspheremachine_object=$(kubectl get vspheremachine -A -o json | jq -c --arg node_name "$node_name" '
    .items[] | select(.status.addresses != null and (.status.addresses[]?.address == $node_name))')

  if [[ $(echo "$vspheremachine_object" | jq -s 'length') -gt 0 ]]; then
    # Fetch IPClaim
    ipclaim=$(kubectl get ipclaims.ipam.metal3.io -A -o json | jq -r --arg vspheremachine_name "$vspheremachine_name" '
      .items[] | select(.metadata.ownerReferences[0].name == $vspheremachine_name)')
    ipclaim_name=$(echo "$ipclaim" | jq -r '.metadata.name')
    ipclaim_namespace=$(echo "$ipclaim" | jq -r '.metadata.namespace')

    # Fetch IPAddress
    ipcaddress=$(kubectl get ipaddresses.ipam.metal3.io -A -o json | jq -r \
      --arg ipclaim_name "$ipclaim_name" \
      --arg ipclaim_namespace "$ipclaim_namespace" '
      .items[] | select(.spec.claim.name == $ipclaim_name and .spec.claim.namespace == $ipclaim_namespace)')
    ipcaddress_name=$(echo "$ipcaddress" | jq -r '.metadata.name')
    ipcaddress_namespace=$(echo "$ipcaddress" | jq -r '.metadata.namespace')
    return 0
  else
    return 1
  fi
}

# === Execution Starts Here ===

# Step 1: Drain Node (if exists)
if ! check_node; then
  console "Node $node_name does not exist, skipping"
  [[ "$force" == "false" ]] && exit 1
else
  run_cmd $drain
fi

# Step 2: Delete Machine
if check_machine; then
  run_cmd "kubectl delete machine -n $machine_namespace $machine_name"
  for i in {1..3}; do
    if [[ $(echo "$machine_object" | jq 'length') -gt 0 ]]; then
      console "Machine $machine_name still exists, patching finalizers"
      run_cmd "kubectl patch machine -n $machine_namespace $machine_name --type=merge -p '{\"metadata\": {\"finalizers\": []}}'"
    fi
  done
else
  console "Machine object ($node_name) does not exist, ignoring"
fi

# Step 3: Delete VSphereMachine
if check_vspheremachine; then
  run_cmd "kubectl delete vspheremachine -n $vspheremachine_namespace $vspheremachine_name"

  if check_vspheremachine; then
    console "VSphereMachine still exists, patching finalizers"
    run_cmd "kubectl patch vspheremachine -n $vspheremachine_namespace $vspheremachine_name --type=merge -p '{\"metadata\": {\"finalizers\": []}}'"
    run_cmd "kubectl delete vspheremachine -n $vspheremachine_namespace $vspheremachine_name"
  fi

  # Step 4: Delete IPClaim and IPAddress
  if [[ -n "$ipclaim_name" ]]; then
    run_cmd "kubectl delete ipclaims.ipam.metal3.io -n $ipclaim_namespace $ipclaim_name"
    if [[ -n "$ipcaddress_name" ]]; then
      run_cmd "kubectl delete ipaddresses.ipam.metal3.io -n $ipcaddress_namespace $ipcaddress_name"
    fi
  fi
else
  console "VSphereMachine object ($node_name) does not exist"
fi

# Step 5: Delete node forcibly
run_cmd $delete_node

# Step 6: Restart all CAPV-related pods
console "Restarting all CAPV pods..."
kubectl get pods -A | grep cap | while read line; do
  namespace=$(echo $line | awk '{print $1}')
  podname=$(echo $line | awk '{print $2}')
  kubectl delete pod -n $namespace $podname
done
