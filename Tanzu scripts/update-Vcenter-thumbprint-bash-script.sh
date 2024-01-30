#!/bin/bash

# Writer: Daniel Mandelblat
# Date: 30/01/2024
# Descrption: This script will update Vcenter thumbprint on all the clusters that existed in the kubeconfig file

#Stop on failure
set -e

msg="This script will access to the management cluster and will path all clusters with the new vcenter thumbprint!"
echo $msg

echo $1
#Get management cluster name
if [ $1 ]
then
        mgmt_cls=$1
else
        read -p "Please enter management cluster context name: " mgmt_cls
fi

#Remove spaces from the context name
mgmt_cls=$(echo $mgmt_cls | sed 's/ //g')
echo "Swithing to received managemnet cluster context ($mgmt_cls)..."
kubectl config use-context $mgmt_cls


for secret in $(kubectl get secret -A | grep cpi-addon | awk '{print $2}')
do

        #Split only the cls name
        cls_name="$(echo $secret|| sed 's/-vsphere-cpi-addon//g') "

        echo "Running on cluster: $secret"
        kubectl get secret $secret -o jsonpath={.data.values\\.yaml} | base64 -d > "$secret.yml"
        kubectl create secret generic $secret --type=tkg.tanzu.vmware.com/addon --from-file=values.yaml="$secret.yml" --dry-run=client -o yaml | kubectl replace -f -
        kubectl label secret $secret tkg.tanzu.vmware.com/cluster-name=$cls_name
        kubectl label secret $secret tkg.tanzu.vmware.com/addon-name=vsphere-cpi
        echo "Cluster $cls_name pathing - done!"
done

