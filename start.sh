#!/bin/bash

if [[ -n "$SCRIPT" || -f "/data/script.sh" ]]
then
    echo "> we have a script"
else
    echo "> error: not script received, either specify the \$SCRIPT environment variable, or mount such that /data/script.sh exists"
    exit 1
fi

echo "> receiving image..."
cat > /tmp/img
type=`file -b /tmp/img`

echo "> received file of type $type"
if [[ $type = *"Zip"* ]]; then
    echo ">   decompressing..."
    unzip /tmp/img -d /tmp
    rm /tmp/img
    unzipped=`ls -1 /tmp/*.img`
    mv $unzipped /tmp/img
fi
type=`file -b /tmp/img`
if [[ $type != *"boot sector"* ]]; then
    echo "> error: it looks like the provided file is not a valid image"
    exit 1
fi

echo "> creating boot mount point"
mkdir /tmp/boot

echo "> trying to find boot partition to modify"
count=`fdisk -l /tmp/img | grep FAT32 | wc -l`
if [[ "$count" != "1" ]]; then
    echo "> error: I didn't find exactly 1 FAT32 partition in image, I found $count instead. I'm not sure how to handle that."
    exit 1
fi
offset=`fdisk -l /tmp/img | grep FAT32 | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2`
real_offset=`echo "$offset*512" | bc`

echo "> mounting boot partition"
mount -o loop,offset=$real_offset /tmp/img /tmp/boot/

echo "> unmounting boot partition"
umount /tmp/boot

echo "> creating root mount point"
mkdir /tmp/root

echo "> trying to find root partition to modify"
count=`fdisk -l /tmp/img | grep Linux | wc -l`
if [[ "$count" != "1" ]]; then
    echo "> error: I didn't find exactly 1 Linux partition in image, I found $count instead. I'm not sure how to handle that."
    exit 1
fi
offset=`fdisk -l /tmp/img | grep Linux | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2`
real_offset=`echo "$offset*512" | bc`

echo "> mounting root partition"
mount -o loop,offset=$real_offset /tmp/img /tmp/root/

if [[ -n "$SCRIPT" ]]
then
    echo "$SCRIPT" > /tmp/script.sh
    chmod 755 /tmp/script.sh
    /tmp/script.sh
fi

if [[ -f "/data/script.sh" ]]
then
    bash /data/script.sh
fi

echo "> unmounting root partition"
umount /tmp/root/

echo "> the image is now being transfered back, this container will exit when finished"
>&2 cat /tmp/img