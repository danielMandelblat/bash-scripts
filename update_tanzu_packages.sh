#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 30/01/2024
# Descrption: This script will update current Tanzu clsuter packages

# set -e 

function error(){
	msg=$1

	echo "Error: $1"
	exit 1
}

function log(){
	msg=$1

	echo "Info: $msg"
}


# Check Tanzu is installed on the current machine
command -v  tanzu > /dev/null || error "Tanzu tool is not exist!"


# Update package 
function update(){
	pkg=$1
	curr_version=$2
	latest_version=$3
	namespace=$4

	log "Updating package [$pkg] from version [$curr_version] -> [$3]"
	cmd="tanzu package installed update $pkg --version $latest_version --namespace $namespace"
	log "Executing: $cmd"
	eval $cmd
}
	

function kick(){
	pkg=$1
        namespace=$2

        log "Kicking package: $pkg"
        cmd="tanzu package installed kick $pkg --namespace $namespace --yes"
        log "Executing: $cmd"
        eval $cmd

}


# Iterate over all the packages
tanzu package installed list -A  | tail -n +3 |
while read pkg; do
	# Parse the package information
	namespace="$(echo $pkg | awk '{print $1}')"
	name="$(echo $pkg | awk '{print $2}')"
	pkg_name="$(echo $pkg | awk '{print $3}')"
	curr_version="$(echo $pkg | awk '{print $4}')"
	state="$(echo $pkg | awk '{print $6}')"

	# Check fior the latest version
	latest_version=`tanzu package available get $pkg_name  -n $namespace | tail -n 1 | awk '{print $1}'`

	# Update package id there is a new version
	if [[ $latest_version == $curr_version ]]
	then
		echo "Package ($name) version ($curr_version) is up to date!"
	else
		echo "Package ($name) installed version is [$curr_version] and the latest version is [$latest_version]"

		# Update the package 
		update $name $curr_version $latest_version $namespace
	fi

	# Kick package id unhealthy state
	if [[ $state == "failed" ]]
	then
		log "Package [$pkg] state is unhealthy"
		kick $name $namespace
	fi

done
