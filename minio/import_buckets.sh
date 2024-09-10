#!/bin/bash
# define credentials
user="minio"
pass="minio"

# Create new alias
mc alias set local_minio http://127.0.0.1:9000 $user $pass

# Set your MinIO alias for the local MinIO instance
LOCAL_ALIAS="local_minio"   # The alias for your local MinIO

# Define the path to the local folder where buckets are exported
LOCAL_FOLDER="/path/to/exported/buckets"  # Replace with the actual path to your local folder

# Define the list of buckets to mirror
buckets=("bucket1" "bucket2" "bucket3")  # Add your bucket names here

# Loop through each bucket and mirror to local MinIO
for bucket in "${buckets[@]}"
do
  echo "Mirroring $bucket from $LOCAL_FOLDER to $LOCAL_ALIAS..."
  mc mirror --overwrite --remove "$LOCAL_FOLDER/$bucket" "$LOCAL_ALIAS/$bucket"
  
  if [ $? -eq 0 ]; then
    echo "Successfully mirrored $bucket."
  else
    echo "Error occurred while mirroring $bucket."
  fi
done
