#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 05/03/2024
# Descrption: This script updating the Tanzu cluster thumbprint to the new one.
# Example:  script.sh <vcenter_url> <cluster>, script.sh vcenter.net devops-cls

set -eE

vcenter_server=$1
cluster=$2
mgmt_cls=$( tanzu cluster list --include-management-cluster -A | grep management | awk '{print $1}')
mgmg_context=$(cat ~/.kube/config | grep $mgmt_cls | grep @ | awk '{print $2}' | tail -n 1)

function get_thumbprint(){
        # log "Getting (${vcenter_server}) Vcenter thumbprint..."
        thumbprint=$(openssl s_client -connect ${vcenter_server}:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout -in /dev/stdin | cut -d "=" -f 2)
        echo $thumbprint
}

function log(){
        msg=$1
        echo "Info: $msg"
}

function exec(){
        cmd=$@
        echo "$cmd"
}


function switch_mgmg_context(){
        kubectl config use-context $mgmg_context
}

function update(){
        cluster=$1

        log "Switch to the managemnet cluster"
        switch_mgmg_context

        log "Build necessary variables"
        context=$(kubectl config get-contexts  | grep $cluster | head -n 1 | awk '{print $1}')
        cpi_addon=$(kubectl get secret -A | grep cpi-addon | grep $cluster | awk '{print $2}')
        ns=$(kubectl get secret -A | grep cpi-addon | grep $cluster | awk '{print $1}')

        echo "Debug: $cluster, $context, $cpi_addon, $ns"

        # Start here
        log "Updating cluster (${cluster}@${ns}) with [${thumbprint}] thumbprint"

        log "1. Update the $cluster-vsphere-cpi-addon secret in the management cluster context"
        values=$(kubectl get secret $cpi_addon -n $ns -ojson | jq -r '.data."values.yaml"' | base64 -d | sed "s/tlsThumbprint.*/tlsThumbprint: ${thumbprint}/g" | base64 | tr -d '\n')

        log "Patch current secret"
        kubectl patch secret $cpi_addon -n $ns --patch="{\"data\": {\"values.yaml\": \"$values\"}}"
        kubectl label secret $cpi_addon -n $ns tkg.tanzu.vmware.com/cluster-name=$cluster
        kubectl label secret $cpi_addon -n $ns tkg.tanzu.vmware.com/addon-name=vsphere-cpi

        log "Switch to the workload context"
        kubectl config use-context $context

        values=$(kubectl get secret -n tkg-system vsphere-cpi-data-values -ojson | jq -r '.data."values.yaml"' | base64 -d | sed "s/tlsThumbprint:.*/tlsThumbprint: ${thumbprint}/g" | base64 | tr -d '\n')

        # Patch current secret
        kubectl -n tkg-system patch secret vsphere-cpi-data-values --patch="{\"data\": {\"values.yaml\": \"${values}\"}}"

        kubectl get po -A | grep vsphere-cloud-controller-manager | while read line; do
                ns=$(echo $line | awk '{print $1}')
                pod=$(echo $line | awk '{print $2}')

                kubectl -n $ns delete pod $pod
        done

        log "Switch to the managemnet cluster"
        switch_mgmg_context

        log "Patch vsphereclusters object"
        ns=$(kubectl get vsphereclusters -A | grep $cluster | awk '{print $1}')
        obj=$(kubectl get vsphereclusters -A | grep $cluster | awk '{print $2}')

        log "Patch vspherecluster $obj"
        kubectl -n $ns patch vspherecluster $obj -ojson --type=merge --patch="{\"spec\": {\"thumbprint\": \"${thumbprint}\"}}"

        log "Patch cluster object"
        result=$(kubectl get cluster $cluster -n $ns  -oyaml | grep Thumbprint | wc -l)
        if (( $result >= 1 ))
        then
                log "Pathing: kubectl -n $ns get cluster $cluster -oyaml | grep Thumbprint"
        else
                log "Cluster (${cluster}) is not holdiong thumprint on the [cluster] object"
        fi

        log "5. Edit the webhook configurations in the management cluster context to allow updates to the VSphereVM objects"
        kubectl scale deploy -n capv-system capv-controller-manager --replicas=0

        kubectl patch validatingwebhookconfiguration capv-validating-webhook-configuration --patch '{"webhooks": [{"name": "validation.vspherevm.infrastructure.x-k8s.io", "failurePolicy": "Ignore"}]}'

        log "6. Edit the VSphereVM objects with the updated thumbprint value with the following command"
        kubectl get vspherevm -l cluster.x-k8s.io/cluster-name=$cluster -n $ns --no-headers=true | awk '{print $1}' | xargs kubectl patch vspherevm -n $ns --type='merge' --patch "{\"spec\":{\"thumbprint\":\"${thumbprint}\"}}"

        kubectl scale deploy -n capv-system capv-controller-manager --replicas=1
}


if [[ $# == 2 ]]
then
        # Get thumprinit
        thumbprint=$(get_thumbprint)

        if [[ $cluster == "all" ]]
        then
                log "Updating all clusters: ${thumbprint}"
        else
                read -p "Are sure you want to update the cluster (${cluster}) with the following thumbprint [$vcenter_server  -> $thumbprint], y/n? " confirm
                if [[ $confirm == "y" ]]
                then
                        update $cluster
                else
                        echo "Action cancled by user!"
                        exit -1
                fi
        fi
else
        log "Length of the argumnets ($#) is no valid: script.sh vcenter_url cluster_name"
        exit -1
fi

