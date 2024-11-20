#!/bin/bash

# rpif2fs.sh : Raspberry Pi Ext4 to F2FS live image converter
#
# Usage             : sudo bash rpif2fs.sh /path/to/zipped/image.{img/raw}.xz
# Requirements      : f2fs-tools, xz, kpartx
# Supported image   : Official Raspberry Pi OS, AlmaLinux
#
# (c) 2024. David Eleazar

# ANSI colors
NC='\033[0m'
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BROWN='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LGRAY='\033[0;37m'
DGRAY='\033[1;30m'
LRED='\033[1;31m'
LGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LBLUE='\033[1;34m'
LPURPLE='\033[1;35m'
LCYAN='\033[1;36m'
WHITE='\033[1;37m'

# Global variables
XZ_IMG=$1
MOUNT_PARENT=/mnt/rpif2fs
TEMP_FS_FILE=/tmp/rpif2.fs
MOUNT_DIR_ARRAY=( "$MOUNT_PARENT/bootfs" "$MOUNT_PARENT/rootfs" )
LOOP_DEVICES=()

function sanity_check {
    echo -e "${LBLUE}Sanity checking . . .${NC}"

    if [ "$(id -u)" != "0" ]; then
        echo -e "${WHITE}Usage: sudo bash rpif2fs.sh /path/to/image.img.xz${NC}"
        echo "Where /path/to/image.img.xz is path to compressed live image."
        echo -e "_____"
        echo -e "${LRED}ERROR: Root access denied. Please run as root.${NC}"
        exit 1
    fi

    if [ "$1" == "" ]; then
        echo -e "${WHITE}Usage: sudo bash rpif2fs.sh /path/to/image.img.xz${NC}"
        echo "Where /path/to/image.img.xz is path to compressed live image."
        echo "_____"
        echo -e "${LRED}ERROR: You must supply the path to the compressed image.${NC}"
        exit 2
    fi

    echo -e "${LGREEN}Environment is sane.${NC}"
}

function install_dependencies {
    if [[ ! -z $(which dnf) ]]; then
        PM=dnf
    elif [[ ! -z $(which apt) ]]; then
        PM=apt
    else
        echo -e "${YELLOW}No supported package manager found.${NC}"
    fi

    $PM install xz f2fs-tools kpartx -y
}

function extract_file {
    echo -e "${LGREEN}Extracting $XZ_IMG . . .${NC}"
    xz -dfkv $1
}

function get_extracted_file_path {
    echo "$(dirname $1)/$(basename -s .xz $1)"
}

function get_root_loop_partition {
    kpartx -av $1 | grep "loop..p2" | awk -F" " '{print $3}'
}

function map_and_get_loop_devices {
    kpartx -av $1 | grep "loop" | awk -F" " '{print $3}'
}

function map_and_mount_devices {
    for ((idx=0; idx<${#LOOP_DEVICES[@]}; ++idx)); do
        echo -e "${LBLUE}Mounting /dev/mapper/${LOOP_DEVICES[idx]} to ${LGREEN}${MOUNT_DIR_ARRAY[idx]}${NC}"
        mount "/dev/mapper/${LOOP_DEVICES[idx]}" "${MOUNT_DIR_ARRAY[idx]}"
    done
}

function create_mount_dir {
    # create boot partition first
    for ((idx=0; idx<${#MOUNT_DIR_ARRAY[@]}; ++idx)); do
        echo -e "${LGREEN}Creating directory ${MOUNT_DIR_ARRAY[idx]}${NC}"
        mkdir -p ${MOUNT_DIR_ARRAY[idx]}
    done
}

function calculate_fs_size {
    local directory=$1
    local percent_margin=25
    size="$(du -cs $directory | grep "total" | awk -F" " '{print $1}')"

    # we add a bit margin of free space to the designated temporary drive target
    size=$((($size * $percent_margin / 100) + $size))

    echo $size
}

function create_and_mount_temporary_f2fs_drive {
    local size=$1
    dd if=/dev/zero of=$TEMP_FS_FILE bs=1024 count=$size
    mkfs.f2fs $TEMP_FS_FILE
    mkdir -p $MOUNT_PARENT/tmp
    mount $TEMP_FS_FILE $MOUNT_PARENT/tmp
}

function backup_root_content {
    rsync -axv $MOUNT_PARENT/rootfs/. $MOUNT_PARENT/tmp
}

function format_root_as_f2fs {
    local loop=$1
    
    echo -e "${LRED}Formatting live image root partition as F2FS . . . ${NC}"
    umount $MOUNT_PARENT/rootfs
    wipefs -a /dev/mapper/$loop
    mkfs.f2fs /dev/mapper/$loop
}

function patch_system_file {
    local loop=$1

    # get fstab settings for root partition
    FSTAB_ROOT_ENTRY=$(cat $MOUNT_PARENT/tmp/etc/fstab | grep "ext4")
    FSTAB_ROOT_ID=$(awk -F' ' '{print $1}' <<< $FSTAB_ROOT_ENTRY)

    # start patching fstab root entry line
    if [[ "$FSTAB_ROOT_ID" == *"PART"* ]]; then
        # if the fstab entry using PARTUUID as identifier, we use it as well
        echo -e "${LGREEN}Patching fstab PARTUUID data . . .${NC}"
        ROOT_ID_VALUE=$(blkid -o value -s PARTUUID /dev/mapper/$loop)
        ROOT_ID="PARTUUID=$ROOT_ID_VALUE"
    else
        # the fstab entry not using PARTUUID, probably using UUID
        echo -e "${LBLUE}Patching fstab UUID data . . .${NC}"
        ROOT_ID_VALUE=$(blkid -o value -s UUID /dev/mapper/$loop)
        ROOT_ID="UUID=$ROOT_ID_VALUE"
    fi

    FSTAB_ROOT_ENTRY=$(sed -e "s/$FSTAB_ROOT_ID/$ROOT_ID/g" <<< $FSTAB_ROOT_ENTRY)

    echo -e "${LBLUE}Patching fstab FS type . . .${NC}"
    FSTAB_ROOT_ENTRY=$(sed -e "s/ext4/f2fs/g" <<< $FSTAB_ROOT_ENTRY)
    
    echo -e "${LBLUE}Patching fstab FS attribute . . .${NC}"
    FSTAB_ROOT_ENTRY=$(sed -e "s/defaults,noatime/defaults,noatime,discard/g" <<< $FSTAB_ROOT_ENTRY)

    echo -e "${LGREEN}Storing patched line to fstab file . . .${NC}"
    sed -i "/.*ext4.*/c $FSTAB_ROOT_ENTRY" $MOUNT_PARENT/tmp/etc/fstab

    # get cmdline.txt content
    CMDLINE_ENTRY=$(cat $MOUNT_PARENT/bootfs/cmdline.txt)

    echo -e "${LBLUE}Patching cmdline.txt root identifier . . .${NC}"
    CMDLINE_ENTRY=$(sed -e "s/ext4/f2fs/g" <<< $CMDLINE_ENTRY)

    echo -e "${LBLUE}Patching cmdline.txt root FS type . . .${NC}"
    CMDLINE_ROOT=$(echo $CMDLINE_ENTRY | awk -F'root=' '{print $2}' | awk -F' ' '{print $1}')
    CMDLINE_ENTRY=$(sed -e "s/$CMDLINE_ROOT/$ROOT_ID/g" <<< $CMDLINE_ENTRY)

    echo -e "${LGREEN}Storing patched line to fstab file . . .${NC}"
    sed -i "/.*ext4.*/c $CMDLINE_ENTRY" $MOUNT_PARENT/bootfs/cmdline.txt

    # For debugging only. Uncomment lines below if needed.
    # echo "$ROOT_ID_VALUE"
    # echo "$FSTAB_ROOT_ENTRY"
    # echo "$CMDLINE_ENTRY"
    # read -p "Press enter to continue . . . "
}

function restore_root_content {
    local loop=$1

    echo -e "${LGREEN}Copy back old root partition content from temporary FS . . . ${NC}"
    mount /dev/mapper/$loop $MOUNT_PARENT/rootfs
    rsync -axv $MOUNT_PARENT/tmp/. $MOUNT_PARENT/rootfs
}

function remove_temporary_drive {
    rm -rf $TEMP_FS_FILE
}

function unmount_directories {
    for ((idx=0; idx<${#MOUNT_DIR_ARRAY[@]}; ++idx)); do
        echo -e "${YELLOW}Unmounting ${MOUNT_DIR_ARRAY[idx]}${NC}"
        umount ${MOUNT_DIR_ARRAY[idx]}
    done

    echo -e "${YELLOW}Unmounting $MOUNT_PARENT/tmp${NC}"
    umount $MOUNT_PARENT/tmp
}

function remove_mount_dir {
    echo -e "${YELLOW}Deleting parent mount directory . . .${NC}"
    rm -rf $MOUNT_PARENT
}

function delete_loop_devices {
    echo -e "${YELLOW}Deleting loop devices map of ${LGREEN}$1 . . .${NC}"
    kpartx -dv $1
}

function rename_extracted_file {
    local dirname=$(dirname $1)
    local filename=$(basename $1)
    local extension="${filename##*.}"
    local filename=$(echo $filename | awk -F'.' '{print $1}')

    filename="$filename-f2fs"
    target="$dirname/$filename.$extension"
    mv $1 $target

    echo $target
}

function compress_modified_image {
    echo -e "${LGREEN}Compressing patched image . . .${NC}"
    xz -zfv8 $1
}

function main() {
    sanity_check $@
    install_dependencies

    extract_file $XZ_IMG
    
    EXTRACTED_FILE=$(get_extracted_file_path $XZ_IMG)
    LOOP_DEVICES=( $(map_and_get_loop_devices $EXTRACTED_FILE) )
    ROOT_LOOP=$(get_root_loop_partition $EXTRACTED_FILE)
    
    create_mount_dir
    map_and_mount_devices

    FS_SIZE=$(calculate_fs_size $MOUNT_PARENT/rootfs)
    
    create_and_mount_temporary_f2fs_drive $FS_SIZE
    backup_root_content

    echo -e "${YELLOW}The live image content was backed up and ready to be formatted.${NC}"
    read -p "Press any key to continue . . ."

    format_root_as_f2fs $ROOT_LOOP
    patch_system_file $ROOT_LOOP
    restore_root_content $ROOT_LOOP

    echo -e "${LGREEN}The live image content was restored.${NC}"
    read -p "Press any key to continue . . ."

    # Cleanup
    unmount_directories
    delete_loop_devices $EXTRACTED_FILE
    remove_mount_dir
    remove_temporary_drive

    # Compress the patched and converted image
    PATCHED_FILE=$(rename_extracted_file $EXTRACTED_FILE)
    compress_modified_image $PATCHED_FILE

    echo -e "${WHITE}Done converting image.${NC}"
    echo -e "${WHITE}The patched image is ${LGREEN}${PATCHED_FILE}.xz${NC}"
}

main $@
