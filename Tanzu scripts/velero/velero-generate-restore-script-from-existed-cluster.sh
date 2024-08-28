#!/bin/bash
# Writer: Daniel Mandelblat
# Date: 27/08/2024
# Description: 
# if you planning to migrate existed running K8s environment and,  
# you backing up your cluster with the Velero tool, 
# you can use this script to generate a BASH script that can restore on the destination cluster - by copy and paste generated BASH script.

# get  storage location
velero_data="$(kubectl get -n velero backupstoragelocations.velero.io -ojson | jq -r '.items[] | select(.status.phase | contains("Available"))' | jq -cs '.[0]')"
velero_data_prefix="$(echo $velero_data | jq -r '.spec.objectStorage.prefix')"
velero_data_bucket="$(echo $velero_data | jq -r '.spec.objectStorage.bucket')"
velero_data_server="$(echo $velero_data | jq -r '.spec.config.s3Url')"
velero_data_region="$(echo $velero_data | jq -r '.spec.credential.name')"
velero_data_cred_name="$(echo $velero_data | jq -r '.spec.credential.name')"
velero_data_cred_key="$(echo $velero_data | jq -r '.spec.credential.key')"
velero_data_cred_username="$(echo $velero_data | jq -r '.spec.credential.name')"
velero_cred_encoded="$(eval "kubectl -n velero get secret $velero_data_cred_name -ojson | jq -r '.data.$velero_data_cred_key'" | base64 -d)"
velero_cred_encoded_username="$(echo $velero_cred_encoded | awk '{print $2}' | cut -d "=" -f 2)"
velero_cred_encoded_password="$(echo $velero_cred_encoded | awk '{print $3}' | cut -d "=" -f 2)"
last_backup="$(velero backup get | tail -n 1 | awk '{print $1}')"
echo -e "\n\n\n"

cat <<EOF
echo "# Copy and paste the below code on the source cluster"
sudo apt update
sudo apt install jq -y
# Install Velero
wget https://github.com/vmware-tanzu/velero/releases/download/v1.14.1/velero-v1.14.1-linux-amd64.tar.gz
tar -xvf velero-v1.14.1-linux-amd64.tar.gz
sudo mv velero-v1.14.1-linux-amd64/velero /usr/local/bin/
velero version
echo -e "[default]\naws_access_key_id=$velero_cred_encoded_username\naws_secret_access_key=$velero_cred_encoded_password" > credentials-velero
velero install \
  --provider aws \
  --image velero/velero:v1.14.0 \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket $velero_data_bucket \
  --secret-file ./credentials-velero \
  --use-node-agent \
  --use-volume-snapshots=false \
  --uploader-type kopia \
  --default-volumes-to-fs-backup \
  --namespace velero \
  --prefix $velero_data_prefix\
  --backup-location-config region=$velero_data_region,s3ForcePathStyle="true",s3Url=$velero_data_server
velero restore create $last_backup --from-backup $last_backup --wait
EOF
