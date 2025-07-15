#!/bin/bash

if [[ -n "$SCRIPT" || -f "/data/script.sh" || -n "$FIRSTBOOTSCRIPT" || -f "/data/firstbootscript.sh" ]]
then
    echo "> we have a script/firstbootscript"
else
    echo "> error: not script or firstbootscript received, either specify the \$SCRIPT or \$FIRSTBOOTSCRIPT environment variables, or mount such that /data/script.sh or /data/firstbootscript.sh exists"
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

if [[ -n "$FIRSTBOOTSCRIPT" || -f "/data/firstbootscript.sh" ]]
then
    echo "> rc.local firstbootscript hook"
    if [[ -f /tmp/root/etc/rc.local ]]
    then
        cp /tmp/root/etc/rc.local /tmp/root/etc/rc.local.bkp
    fi
    echo '#!/bin/sh -e' > /tmp/root/etc/rc.local
    chmod 750 /tmp/root/etc/rc.local

    if [[ -n "$FIRSTBOOTSCRIPT" ]]
    then
        echo "$FIRSTBOOTSCRIPT" >> /tmp/root/etc/rc.local
    fi

    if [[ -f "/data/firstbootscript.sh" ]]
    then
        cp /data/firstbootscript.sh /tmp/root
        chmod 555 /tmp/root/firstbootscript.sh
        echo "/firstbootscript.sh" >> /tmp/root/etc/rc.local
        echo 'if [ $? -ne 0 ]; then exit 1; fi' >> /tmp/root/etc/rc.local
        echo "rm -f /firstbootscript.sh" >> /tmp/root/etc/rc.local
    fi

    echo 'if [[ -f /tmp/root/etc/rc.local.bkp ]]; then cp /tmp/root/etc/rc.local.bkp /tmp/root/etc/rc.local; rm -f /tmp/root/etc/rc.local.bkp; else rm -f /etc/rc.local; fi' >> /tmp/root/etc/rc.local
    echo "exit 0" >> /tmp/root/etc/rc.local
fi

echo "> unmounting root partition"
umount /tmp/root/

echo "> the image is now being transfered back, this container will exit when finished"
>&2 cat /tmp/img