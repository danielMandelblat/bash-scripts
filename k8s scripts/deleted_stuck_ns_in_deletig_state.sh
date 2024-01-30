#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 24/01/2024
# Description: this script deleting a namesapce in `terminating`  state for long time

set -e

if [[ -z $1 ]]
then
	error "No namesapce name has been sent"
else
	ns=$1
fi


function error(){
	msg=$1

	echo "Error: $msg"
	exit -1
}


function delete(){
	kubectl get ns $ns -ojson | jq 'del(.spec.finalizers)' > tmp.json
	kubectl proxy &
	
	pid=$1
	curl -k -H "Content-Type: application/json" -X PUT --data-binary @tmp.json http://127.0.0.1:8001/api/v1/namespaces/$ns/finalize
	kill -9 $pid
}

delete
