#!/bin/bash

user="minio"
pass="minio"
x_days_ago=7

# Create new alias
mc alias set local_minio http://127.0.0.1:9000 $user $pass

# delete files older then X days:
mc ls local_2/ | awk '{print $5}' | while read line; do mc find local_minio/$line --older-than "${x_days_ago}d" |  xargs -I {} -P 25 mc rm {} ; done
