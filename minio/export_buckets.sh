#!/bin/bash

user="minio"
pass="minio"
x_days_ago=7
export_path="/tmp/buckets"

# Create new alias
mc alias set local_minio http://127.0.0.1:9000 $user $pass

# export buckets
mkdir -p $export_path
mc ls local_2/ | awk '{print $5}' | while read line; do mc mirror local_minio/$line $export_path/$line ; done

