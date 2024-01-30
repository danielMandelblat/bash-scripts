#!/bin/bash

# filename: get_pvc_usage.sh
# author:  daniel.mandelblat1@hp.com
# create date: 09/01/2024
# description: Get desired fodler and print each folder percentage

readonly PARTITION_TO_CHECK="/data"
readonly BLOCK_SIZE="1G"

total=`df --block-size=${BLOCK_SIZE} | grep ${PARTITION_TO_CHECK} | awk '{print $3}'`

function percent(){
    size=$1
    echo $(($size/$total))
}

readonly unit="percent"

echo "<prtg>"
du $PARTITION_TO_CHECK -d 1 --block-size=$BLOCK_SIZE | while read line; do name=`echo $line | awk '{print $2}'`; size=`echo $line | awk '{print $1}'`; percent=$(printf '%.f\n' "$(($size*100*100/$total))e-2") ; echo "<result><channel>$name</channel><value>$percent</value><unit>$unit</unit></result>"; done
echo "</prtg>"
