#!/bin/bash
# filename: check_prtg_free_bytes.sh
# author: DM daniel.mandelblat1@hp.com
# create date: 02/04/2024
# description: a PRTG check that displays free bytes, for various filesystems, ignoring tmpfs, devtmpfs, squashfs. PRTG prefers XML as its output machanism.

# get mount name
cmd="df -T -x tmpfs -x devtmpfs -x squashfs | grep ext4 |  egrep -v 'Filesystem'"

MOUNT=`eval $cmd | awk '{print $7}'`
MOUNT_ARRAY=( $MOUNT )

# get free bytes
FREEB=`eval $cmd | awk '{ print $5}'`
MOUNT_FREEB=( $FREEB )

# get total bytes
PERCENT=`eval $cmd $usage | awk '{ print $6}'`
MOUNT_PERCENT=( $PERCENT )

echo $MOUNT
echo $FREEB
echo $PERCENT

# build the XML file, iterating through two arrays
echo "<prtg>"
n=0
for i in "${MOUNT_ARRAY[@]}"
do
        percent=${MOUNT_PERCENT[n]}
        percent=${percent%\%}
        percent=$((100-percent))
        echo "  <result>"
        echo "    <channel>Freespace on Mount: $i</channel>"
        echo -e "      <value> $percent </value>"
        n=$(($n+1))
        echo "         <unit>percent</unit>"
        echo "         <LimitMode>1</LimitMode>"
        echo "         <LimitMinWarning>10</LimitMinWarning>"
        echo "         <LimitMinError>5</LimitMinError>"
        echo "  </result>"
done

echo "</prtg>"
