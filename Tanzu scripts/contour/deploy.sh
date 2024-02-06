#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 06/02/2024
# Descrption: This script will install/update Contour package for Tanzu

package_name="contour.tanzu.vmware.com"
short_name=$(echo $package_name | cut -d "." -f 1)
namespace="tanzu-system-ingress"
version=""


if [[ $1 != "redeploy" ]]
then
	redeploy=false
else
	redeploy=true
fi


# Get the current namespace
if [[ $namespace != "" ]]
then
	ns=$namespace
else
	ns=$(tanzu package installed list -A | grep $package_name | awk '{print $1}')
fi

# Get latest avilable version
if [[ $version != "" ]]
then
	latest_version=$version
else
	latest_version=$(tanzu package available list contour.tanzu.vmware.com -A | tail -n 1 | awk '{print $3}')
fi

function log(){
	msg=$1
	echo "Info: $msg"
}

function deploy(){
	log "Deploying contour"

	kubectl get ns $ns 2> /dev/null || kubectl create ns $ns

	tanzu package install $short_name \
        --package $package_name \
        --version $latest_version  \
        --values-file contour-data-values.yaml \
        --namespace $ns
}


function update(){
	log "Updating Contour to version $latest_version"
	curr_ns=$(echo $result | awk '{print $1 }')
        curr_name=$(echo $result | awk '{print $2 }')

        tanzu package installed update -n $curr_ns $curr_name --version $latest_version --yes

}

function delete(){
	log "Deleteing Contour from namesapce $ns"
	tanzu package installed delete -n $ns $short_name --yes 
}

function kick(){
	log "Kicking Contour package"
	tanzu package installed kick -n $ns $short_name  --yes
}


# Check if there is an old version?
results=$(tanzu package installed  list -A | grep $package_name | wc -l)

if [[ "$results" -gt "0" ]] && [[ $redeploy == true ]]
then
	delete
	deploy

elif [[ "$results" -gt "0" ]]
then
	update
else
	deploy
fi

kick
