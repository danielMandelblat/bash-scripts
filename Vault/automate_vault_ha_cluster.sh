#!/bin/bash

# Script Name: automate_vault_ha_cluster.sh
# Description: Automates the creation of a HashiCorp Vault High-Availability (HA) cluster.
#               This script provisions the necessary resources, configures Vault nodes, 
#               sets up backend storage (e.g., Consul), and ensures HA failover readiness.
# Last Updated: 2024-12-16
# Created By: Daniel Mandelblat (danielmande@gmail.com)

# Variabels
# =====================
# Declare an associative array
declare -A roles

# Usernames
default_admin="admin"
default_admin_password="Aa123456!"
default_backup_user="backup"
default_backup_user_password="backup-password"

# LDAP configuration
ldap_bind_user="CN=serviceaccount,OU=IT,OU=Accounts,DC=site,DC=net"
ldap_bind_user_password="password"
ldap_server="ldaps://site.net"
ldap_user_dn="CN=Users,DC=site,DC=net"
ldap_group_dn="OU=Groups,DC=site,DC=net"

# Kuberenets Roles[service_account] = "namesapce"
roles["jenkins-sa"]="jenkins"
roles["test-service-account"]="test-namespace"

# Other
namespace="vault"
ingress_url="http://vault.k8s-services.site.net/"

# =====================

setup=$1
set -e 

function execute(){
	cmd="$*"
	echo "Executing: $cmd"
	eval $cmd
}

function execute_master(){
	vault_commands=$*
	cmd="kubectl exec -n $namespace vault-0 -- ${vault_commands}"
	echo "Executing: $cmd"
	eval $cmd
}

# Print welcome banner
echo "Vault setup is begin..."

# Config INR LDAP settings
function ldap_configure(){
	execute_master "vault auth enable ldap"
	execute_master "vault write auth/ldap/config url=$ldap_server userdn=$ldap_user_dn groupdn=$ldap_group_dn binddn=$ldap_bind_user bindpass=$ldap_bind_user_password userattr='sAMAccountName' groupfilter='(|(member={{.UserDN}})(memberUid={{.Username}}))' groupattr='cn' insecure_tls=true"
}

# Unseal the Vault server
function unseal(){
	index=$1
	cat cluster-keys.json  | jq -r '.unseal_keys_b64[]'  | while read line
	do
        	execute_master "vault operator unseal ${line}"
	done
}

# Create admin-policy
function admin_policy(){
kubectl exec -n ${namespace} vault-0 -- /bin/sh -c 'vault policy write admin-policy - <<EOF
path "*" {
capabilities = ["create", "update", "read", "delete", "list"]
}
EOF'
}

# Create read-policy 
function read_policy(){
kubectl -n ${namespace} exec vault-0 -- /bin/sh -c 'vault policy write read-policy - <<EOF
path "*" {
capabilities = ["read"]
}
EOF'
}

function enable_kubernetes_access(){
	# Enable Kuberentes access
	execute_master "vault auth enable kubernetes"

	# Config local Kuberenetes host
	execute_master "vault write auth/kubernetes/config kubernetes_host='https://kubernetes.default.svc' "

	# Create roles
	for key in "${!roles[@]}"
	do
		value=${roles[$key]}
		execute_master "vault write auth/kubernetes/role/$key bound_service_account_names=$key bound_service_account_namespaces=$value policies=read-policy ttl=24h"
	done
}

function create_local_users(){
	# Create admin policy
	admin_policy

	# Enable username and password authentication
	execute_master "vault auth enable userpass"

	# Create the admin user 
	execute_master "vault write auth/userpass/users/$default_admin password=$default_admin_password policies=admin-policy"

	# Create the backup user
	execute_master "vault write auth/userpass/users/$default_backup_user password=$default_backup_user_password policies=read-policy"
}

function wait_to_master_pod(){
	while true
	do
		pod_status=$(kubectl -n $namespace get po vault-0 -ojson | jq -r '.status.containerStatuses[0].started')
		if [[ $pod_status == true ]]
		then
			echo "Vault pod is running, please wait for the next step..."
			break
		else
			echo "Waiting the pod to be running, current state: $pod_status"
			sleep 1
		fi
	done
}

function init_cluster(){
	# Wait for the pod to be running
	wait_to_master_pod

	# Init the cluster
	kubectl exec vault-0 -n $namespace -- vault operator init \
		-format=json > cluster-keys.json
}

function unseal_all(){
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

}

function login(){
	# Login and check the cluster state
	execute_master "vault login ${token}"
	execute_master "vault operator raft list-peers"
}

function config_auth_methods(){
	echo "Configing Active directory (LDAP)"
	ldap_configure

	echo "Creating polices"
	admin_policy
	read_policy

	echo "Creating local admin and backup users"
	create_local_users

	echo "Enabling Kubernetes access"
	enable_kubernetes_access
}

function get_token(){
	# Wait for the pod to be running
	wait_to_master_pod

	# Get the token
	token="$(cat cluster-keys.json | jq -r '.root_token')"
	export token
}

function config_crontab(){
	echo "Patching the root token into a secret"
	kubectl -n $namespace  create secret generic backup-cronjob-secret --dry-run=client -oyaml --save-config --from-literal=VAULT_TOKEN=$token | kubectl -n $namespace apply -f -
}


# Pipeline to config the Vault server
function config(){
	# 1. Init the cluster
	init_cluster

	# 2. Fetch the token
	get_token

	# 3. Unseal cluster
	unseal_all

	# 4. Config access methods
	login
	config_auth_methods

	# 5. Config Backups (Cronjob object)
	config_crontab
}

if [[ $setup == "--config-only" ]]
then
	config
	echo "Vault has been configured successfully"

elif [[ $setup == "access_config" ]]
then
	config_auth_methods
	echo "All the access methods have been configured!"

# Deploy the Helm Chart
elif [[ $setup == "unseal" ]]
then
	get_token
	unseal_all
	echo "Clusters unsealing has been finished!"

else
	# 1. Install Vault
	helm upgrade --install -n $namespace --create-namespace vault vault/ 

	# 2. Config
	config
fi

# Print token
echo "====== Process has been finished ======"
echo "Please login to UI [ $ingress_url ] with this token: $token"
