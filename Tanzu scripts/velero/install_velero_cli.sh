VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r .tag_name) && \
wget https://github.com/vmware-tanzu/velero/releases/download/$VERSION/velero-$VERSION-linux-amd64.tar.gz --no-check-certificate && \
tar -zxvf velero-$VERSION-linux-amd64.tar.gz && \
sudo mv velero-$VERSION-linux-amd64/velero /usr/local/bin/ && \
velero version
