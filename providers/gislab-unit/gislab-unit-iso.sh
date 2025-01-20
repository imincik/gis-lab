#!/bin/bash

set -e


### USAGE
function usage() {
    echo "USAGE: $(basename $0) [OPTIONS]"
    echo "Create GIS.lab base system installation ISO image from Ubuntu Server ISO."
    echo "Script must be executed with superuser privileges."
    echo -e "\nOPTIONS
    -s country code used for choosing closest repository mirror (e.g. SK)
    -t timezone (e.g. Europe/Bratislava)
    -d disk size in GB
    -a swap size in GB (default: 4)
    -k SSH public key file, which will be used for GIS.lab installation or update
    -w working directory with enough disk space (2.5 x larger than ISO image size)
    -i Ubuntu Server installation ISO image file
    -h display this help
    "
    exit 255
}


### OPTIONS
while getopts "s:t:d:a:i:w:k:h" OPTION; do
    case "$OPTION" in
        s) COUNTRY_CODE="$OPTARG" ;;
        t) TIME_ZONE="$OPTARG" ;;
        d) DISK_SIZEGB="$OPTARG" ;;
        a) DISK_SIZE_SWAPGB="$OPTARG" ;;
        k) SSH_PUBLIC_KEY="$OPTARG" ;;
        w) WORK_DIR="$OPTARG"
           ROOT_DIR="$WORK_DIR/root" ;;
        i) SRC_IMAGE="$OPTARG" ;;
        h) usage ;;
        \?) usage ;;
    esac
done


### VARIABLES
SRC_DIR="$(dirname $(readlink -f $0))"
MOUNT_DIR="/tmp/gislab-base-system-iso-mnt"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ISO_ID=v`(cd $SCRIPT_DIR/../.. ; grep ^GISLAB_VERSION system/roles/installation-setup/vars/main.yml | cut -d':' -f 2 | sed -e "s/^ \{1,\}//")`
DATE=$(date '+%Y-%m-%d-%H:%M:%S')


### SANITY CHECKS
if [ -z "$COUNTRY_CODE" \
    -o -z "$TIME_ZONE" \
    -o -z "$SRC_IMAGE" \
    -o -z "$WORK_DIR" \
    -o -z "$SSH_PUBLIC_KEY" \
    -o -z "$DISK_SIZEGB" ]; then
    usage
fi
if [ -z "$DISK_SIZE_SWAPGB" ]; then
    DISK_SIZE_SWAP=4300
else
    DISK_SIZE_SWAP=${DISK_SIZE_SWAPGB}300
fi

DISK_SIZE_ROOT=60000
# boot: 530
# free: 470
DISK_SIZE_STORAGE=$(($DISK_SIZEGB*1000-470-530-$DISK_SIZE_ROOT-$DISK_SIZE_SWAP))
if [ $DISK_SIZE_STORAGE -lt 20000 ]; then
    echo "Invalid disk configuration (storage must be at least the size of 20GB), please check -d and -a flags"
    exit 1
fi

if [ $(id -u) -ne 0 ]; then
    echo "This command can be run only with superuser privileges"
    exit 1
fi

if ! which xorriso >/dev/null; then
    echo "Cannot find 'xorriso' binary. Please install appropriate package."
    exit 1
fi


# mount ISO image, check and keep it for rest of the script
mkdir -p $MOUNT_DIR
sudo mount -o loop $SRC_IMAGE $MOUNT_DIR

if [ ! -d "$MOUNT_DIR/dists/noble" ]; then
    echo "Invalid Ubuntu ISO image file. Ubuntu 22.04 Server ISO is required."
    umount $MOUNT_DIR
    exit 1
fi


### FUNCTIONS
clean_up () {
    mount \
        | grep -q " $MOUNT_DIR " \
        && sudo umount $MOUNT_DIR \
        && rm -rf $MOUNT_DIR
    test -d $WORK_DIR && rm -rf $WORK_DIR
}


### MAIN SCRIPT
mkdir -p $WORK_DIR
mkdir -p $ROOT_DIR


# clean up when something go wrong
trap clean_up SIGHUP SIGINT SIGKILL


# copy ISO image content and umount
rsync -a $MOUNT_DIR/ $ROOT_DIR/
umount $MOUNT_DIR

cd $ROOT_DIR


# boot options
sed -i 's/timeout.*/timeout=0/' $ROOT_DIR/boot/grub/grub.cfg


# generate preseed file
mkdir -p $ROOT_DIR/gislab
cp $SRC_DIR/iso/gislab-autoinstall.yaml.template $ROOT_DIR/gislab/user-data
touch $ROOT_DIR/gislab/meta-data
sed -i "s;###COUNTRY_CODE###;$COUNTRY_CODE;" $ROOT_DIR/gislab/user-data
sed -i "s;###TIME_ZONE###;$TIME_ZONE;" $ROOT_DIR/gislab/user-data
sed -i "s;###DISK_SIZE_ROOT###;$DISK_SIZE_ROOT;g" $ROOT_DIR/gislab/user-data
sed -i "s;###DISK_SIZE_SWAP###;$DISK_SIZE_SWAP;g" $ROOT_DIR/gislab/user-data
sed -i -e 's,---, autoinstall "ds=nocloud-net;s=file:///cdrom/gislab/"  ---,g' $ROOT_DIR/boot/grub/grub.cfg
sed -i -e 's,---, autoinstall "ds=nocloud-net;s=file:///cdrom/gislab/"  ---,g' $ROOT_DIR/boot/grub/loopback.cfg
        
cp $SSH_PUBLIC_KEY $ROOT_DIR/ssh_key.pub

cp $SRC_DIR/iso/configure-apt-proxy.sh $ROOT_DIR/configure-apt-proxy.sh
chmod 0755 $ROOT_DIR/configure-apt-proxy.sh


# change ISO image name
echo "GIS.lab Base System ($ISO_ID)" > $ROOT_DIR/.disk/info

rm -f $ROOT_DIR/boot.catalog

# update md5sum file
rm -f $ROOT_DIR/md5sum.txt
find -type f -print0 \
    | xargs -0 md5sum \
    | grep -v 'boot.catalog' > $ROOT_DIR/md5sum.txt

cd $WORK_DIR

# taken from https://askubuntu.com/questions/1403546/ubuntu-22-04-build-iso-both-mbr-and-efi
#  extract the MBR template for --grub2-mbr (x86 code)
dd if=$SRC_IMAGE bs=1 count=432 of=root/boot_hybrid.img
#  the EFI partition is not a data file inside the ISO any more.
#  7129428d-7137923d : 7137923 - 7129428 + 1 = 8496
dd if=$SRC_IMAGE bs=512 skip=2871452 count=8496 of=root/efi.img
#  pack ISO...
xorriso -as mkisofs -r \
        -V 'GISLAB_Base_System' \
        -o gislab-base-system-${ISO_ID}.iso \
        --grub2-mbr root/boot_hybrid.img \
        -partition_offset 16 \
        --mbr-force-bootable \
        -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b root/efi.img \
        -appended_part_as_gpt \
        -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
        -c '/boot.catalog' \
        -b '/boot/grub/i386-pc/eltorito.img' \
        -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
        -eltorito-alt-boot \
        -e '--interval:appended_partition_2:::' \
        -no-emul-boot \
        root/

# create meta file
cat << EOF >> $WORK_DIR/gislab-base-system-${ISO_ID}.meta
DATE=$DATE
COUNTRY_CODE=$COUNTRY_CODE
TIME_ZONE=$TIME_ZONE
SRC_IMAGE=$(basename $SRC_IMAGE)
SSH_PUBLIC_KEY=$SSH_PUBLIC_KEY
EOF

# cleanup
rm -rf $MOUNT_DIR
rm -rf $ROOT_DIR


### DONE
echo
echo "GIS.lab Base System ISO: $WORK_DIR/gislab-base-system-${ISO_ID}.iso"
echo "GIS.lab Base System ISO meta:  $WORK_DIR/gislab-base-system-${ISO_ID}.meta"
echo

# vim: set ts=8 sts=4 sw=4 et:
