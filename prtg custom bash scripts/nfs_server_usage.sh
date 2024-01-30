#!/bin/bash

# filename: get_pvc_usage.sh
# author:  daniel.mandelblat1@hp.com
# create date: 07/04/2024
# description: Get desired fodler and print each folder size

# Define Path
if [[ ! -z $1 ]]; then path=$1; else path="/data"; fi

# Define size threshold
if [[ ! -z $2 ]]; then threshold=$2; else threshold="200M"; fi

# Define size representation
if [[ ! -z $3 ]]; then block_size=$3; else block_size="K"; fi

# Define unit type
unit="BytesFile" 
volume_size="GigaByte" #MegaByte

# Get folders size
get_size="du ${path} --block-size=1${block_size} -d 1 --threshold=${threshold}  2> /dev/null"

# Get percent sizefrom total
function get_last_change(){
    if [[ -z $1 ]];
    then
            echo -
    else
        echo $(date -r ${1} '+%m-%d-%Y %H:%M:%S')
    fi
}

echo "<prtg>"
echo "$(eval $get_size)" | while read folder; do
    size=$(echo $folder | awk '{print $1}')
    name=$(echo $folder | awk '{print $2}')
    last_change=$(get_last_change $name)

    echo "<result><channel>${name}</channel><value>${size}</value><unit>$unit</unit><VolumeSize>$volume_size</VolumeSize></result>"
done    
echo "</prtg>"
