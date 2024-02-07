#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 06/02/2024
# Descrption: This script will cut the MachineSet object name and all the related machines

set -e

ACTION=$1
CONTEXT=$2
MACHINE_SET=$3

# Log function 
function log(){
    msg=$1
    echo "Info: $msg"
}

# Error function
function error(){
    msg=$1
    echo "Error: $msg"
    exit 1
}

# Validate tools are existed
command -v tanzu > /dev/null || error "Tanzu CLI tool are not existed!"
command -v kubectl > /dev/null || error "kubectl CLI tool are not existed!"

# Build variables
CLS=$(echo $CONTEXT | cut -d @ -f 2)
MGMT_CONTEXT=$(tanzu  context list | grep true | awk '{print $4}')
CURR_CONTEXT=$(kubectl config current-context)


function exec(){
    cmd=$@
    log "Executing: $cmd"
    eval $cmd
}

function switch_context(){
    context=$1
    log "Switching to [$context] context"
    kubectl config use-context $context > /dev/null
}


function cut(){
    # Check the selected machine-set is existed!
    kubectl -n default get machinesets.cluster.x-k8s.io $MACHINE_SET > /dev/null || error "Machine Deployment ($MACHINE_SET) is not existed!" 

    # > Creater shorter name
    # ================================================
    # Check if the ID length is more then 8 characters
    log "Validating machine-set id length"

    min_characters=8

    curr_id=$(echo $MACHINE_SET | rev | awk -F '-' '{print $1}')
    curr_length=$(echo $curr_id | wc -c)

    if (( "$curr_length" <= "$min_characters" ))
    then
        error "Selected machine-set ID [$MACHINE_SET] lentgh is less then $min_characters characters" 
    fi
    characters_to_cut=$((curr_length-5))

    machineset_full_name=$(echo $MACHINE_SET | rev)
    machineset_full_name=${machineset_full_name:characters_to_cut}
    short_name="$( echo $machineset_full_name | rev)"
    # ================================================
    # > Creater shorter name

    # Backup the machine-set yaml
    log "Backing up the current [$MACHINE_SET] machine-set"
    kubectl -n default get machinesets.cluster.x-k8s.io $MACHINE_SET -oyaml > ${MACHINE_SET}.yaml

    # Create new machine-set with a shorter name
    log "Creating new machine-set named: $short_name"
    kubectl -n default patch machinesets.cluster.x-k8s.io $MACHINE_SET --patch='{"metadata": {"name": "'${short_name}'", "resourceVersion": null, "uid": null}, "spec": {"replicas": 0}}' --type=merge --dry-run=client -oyaml | kubectl create -f -

    # Get selector
    selector=$(kubectl -n default get machinesets.cluster.x-k8s.io  $MACHINE_SET -ojson | jq -r '.spec.selector.matchLabels."machine-template-hash"')

    # Get machines
    machines=$(kubectl -n default get machine --selector=machine-template-hash=$selector --no-headers | grep $MACHINE_SET | awk '{print $3}')

    log "Machine-set [$MACHINE_SET] contains $(echo $machines | wc -w) machines: [$machines]"


    # Drain current running machines 
    # >
    # ==============================

    # Switch to the workload cluster
    switch_context $CONTEXT

    # Drain machines
    for machine in $(echo $machines)
    do
        kubectl drain $machine --ignore-daemonsets --delete-emptydir-data
    done

    # >
    # ==============================

    # Switch back to the mgmg cluster
    switch_context $MGMT_CONTEXT
    
    # Delete the current machine set
    kubectl -n default delete machinesets.cluster.x-k8s.io $MACHINE_SET

    # Increase the new machine-set workers count
    workers_count=$(echo $machines | wc -w)

    kubectl -n default patch machinesets.cluster.x-k8s.io $short_name --type=merge --patch='{"spec": {"replicas": '"${workers_count}"' }}'
}



# Start here
######################
# Start `cut` function

# Switch to the managemnt 
switch_context $MGMT_CONTEXT

read -p "Continue with the follwoing argumnets (action=[$ACTION]), (context=[$CONTEXT]), (machineset=[$MACHINE_SET]), type [yes] to continue: " confirm

if [[ $confirm != 'yes' ]]
then
    log "Process canceld by the user."
    exit
fi

function validatior(){
    # Check teh selected machineset is equal to the received context
    machine_set_cls=$(kubectl -n default get machinesets.cluster.x-k8s.io $MACHINE_SET -ojson | jq -r '.spec.clusterName')
    if [[ $machine_set_cls != $CLS ]]
    then
        error "The selected machineset object [$MACHINE_SET] specified different cluster [$machine_set_cls] than the received context [$CONTEXT]. "
    fi
}

# Check which action to run
if [[ $ACTION == 'cut' ]]
then
    if [[ $# -ne 3 ]]
    then
        error "Please send two argumnets: script.sh action (show|cut) context machine_set_name"
    fi

    # Run the validator process
    validatior

    # Start the process to cut the machine-set name
    cut

elif [[ $ACTION == 'show' ]]
then
    # Print all the machine-sets
    kubectl get machinesets.cluster.x-k8s.io -A
fi

# At the end, go back to the original context
switch_context $CURR_CONTEXT