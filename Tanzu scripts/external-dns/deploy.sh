#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 06/02/2024
# Descrption: This script will install/update External-DNS package for Tanzu

# Changable variables
########################################

pkg="external-dns.tanzu.vmware.com"
manual_version="0.13.4+vmware.2-tkg.3"
namespace="tanzu-system-service-discovery"

#########################################
#set -e

if [[ $1 != "redeploy" ]]
then
	redeploy=false
else
	redeploy=true
fi

function log(){
	msg=$1
	echo "Info: $msg"
}

function exec(){
	cmd=$@
	log "Executing: $cmd"
	eval $cmd
}

# Check tanzu tool is existed
command -v tanzu > /dev/null || (log "Tanzu CLI tool is not existed" && exit 1)

# Get cluster name
cls_name=$(kubectl config current-context | cut -d "@" -f 2)

# Select namespace
if [[ $namespace != "" ]]
then
	ns=$namespace
else
	# Get the current namespace
	ns=$(tanzu package installed list -A | grep $pkg | awk '{print $1}')
fi

# Package name
pkg_name=$(echo $pkg | cut -d "." -f 1) 


# Check which version to deploy
if [[ $manual_version ]]
then
	version=$manual_version
else
	version=$(tanzu package available list $pkg -A | tail -n 1 | awk '{print $3}')
fi


search=$(tanzu package installed list -A | grep $pkg)

function fresh_deploy(){
	# Create namespace if not existed
	cmd="kubectl get ns tanzu-system-service-discovery > /dev/null || kubectl create ns $ns"
	exec $cmd

	# Create temp values file
        sed "s/cluster-id/$cls_name/g" values.yaml > tmp.yaml

        # Deploy
        cmd="tanzu package install $pkg_name --package $pkg --version $version --values-file tmp.yaml --namespace $ns"
	exec $cmd

        # Remove temp file
        yes | rm tmp.yaml

        # Create secret with Kereberos details
        cmd="kubectl create secret generic external-dns-kerberos-overlay -n $ns --from-file=overlay-external-dns-kerberos.yaml -o yaml --dry-run=client | kubectl apply -f - "
	exec $cmd

        # Annotate the `external-dns` package using the overlay.
        cmd="kubectl annotate packageinstalls $pkg_name ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=external-dns-kerberos-overlay -n $ns"
	exec $cmd

}

function update(){
	ns=$(echo $search | awk '{print $1}')
        pkg_name=$(echo $search | awk '{print $2}')

        echo "Updating package [$pkg_name] on namespcae [$ns]"

        cmd="tanzu package installed update -n $ns $pkg_name --version $version --yes"
        exec $cmd
}

function delete(){
	curr_name=$(echo $search | awk '{print $2}')
	curr_ns=$(echo $search | awk '{print $1}')


	# Create sa if not existed
	sa="external-dns-tanzu-system-service-discovery-sa"
	cmd="kubectl -n $curr_ns get sa $sa || kubectl create -n $curr_ns sa $sa"
        exec $cmd

	# Delete the package
	cmd="tanzu package installed delete -n $curr_ns $curr_name --yes"
	exec $cmd
}

function kick(){
	cmd="tanzu package installed kick $pkg_name -n $ns --yes"
	exec $cmd
}

# Check if update or install
result="tanzu package installed list -A | grep $pkg | wc -l"


if [[ $(eval $result) == 1 ]] && [[ $redeploy == true ]]
then
	log "redeploying package"
	delete 
	fresh_deploy
elif [[ $(eval $result) == 1 ]]
then
	log "Updating package"
	update
else
	log "Deeploying package"
	fresh_deploy
fi

kick
