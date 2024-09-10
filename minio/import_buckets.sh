#!/bin/bash
# define credentials
user="minio"
pass="minio"

# Set your MinIO alias for the local MinIO instance
LOCAL_ALIAS="local_minio"   # The alias for your local MinIO

# Define the path to the local folder where buckets are exported
LOCAL_FOLDER="/tmp/buckets"  # Replace with the actual path to your local folder

# Create new alias
mc alias set $LOCAL_ALIAS http://127.0.0.1:9000 $user $pass

# Loop through each bucket and mirror to local MinIO
for bucket in $(ls $LOCAL_FOLDER)
do

  echo "Checking if bucket $bucket exists on $LOCAL_ALIAS..."

  # Check if the bucket exists
  mc ls "$LOCAL_ALIAS/$bucket" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Bucket $bucket does not exist. Creating it..."
    mc mb "$LOCAL_ALIAS/$bucket"
    if [ $? -ne 0 ]; then
      echo "Error creating bucket $bucket. Skipping..."
      continue
    fi
  else
    echo "Bucket $bucket already exists."
  fi

  echo "Mirroring $bucket from $LOCAL_FOLDER to $LOCAL_ALIAS..."
  mc mirror --overwrite --insecure --remove "$LOCAL_FOLDER/$bucket" "$LOCAL_ALIAS/$bucket"
  
  if [ $? -eq 0 ]; then
    echo "Successfully mirrored $bucket."
  else
    echo "Error occurred while mirroring $bucket."
  fi
done
