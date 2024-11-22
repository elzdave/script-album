#!/bin/bash

# rpif2fs.sh : Raspberry Pi Ext4 to F2FS live image converter
#
# Usage             : sudo bash rpif2fs.sh ["/path/to/zipped/image.{img/raw}.xz"]
#                     The path is optional. If you didn't supply one, the file
#                     selection dialog will open to choose.
#
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
XZ_IMG="$1"
MOUNT_PARENT=/mnt/rpif2fs
TEMP_FS_FILE=/tmp/rpif2.fs

# Those values will be set later by functions below
LOOP_DEVICES=()
MOUNT_DIR_ARRAY=()
PATCHED_FILE=
EXTRACTED_FILE=
MOUNTED_BOOT_PART=
MOUNTED_ROOT_PART=
MOUNTED_TMP_PART=$MOUNT_PARENT/tmp

function sanity_check {
    echo -e "${LBLUE}Sanity checking . . .${NC}"

    if [ "$(id -u)" != "0" ]; then
        echo -e "${WHITE}Usage: sudo bash rpif2fs.sh /path/to/image.img.xz${NC}"
        echo "Where /path/to/image.img.xz is path to compressed live image."
        echo -e "_____"
        echo -e "${LRED}ERROR: Root access denied. Please run as root.${NC}"
        exit 1
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

function select_file {
    local home_dir=$(getent passwd $(logname) | cut -d: -f6)
    if [[ ! -z $(which kdialog) ]]; then
        XZ_IMG=$(kdialog --title="Choose Live Image File" --getopenfilename $home_dir '*.xz')
    else
        XZ_IMG=$(zenity --file-selection --title="Choose Live Image File" --filename=$home_dir)  
    fi
}

function extract_file {
    echo -e "${LBLUE}Extracting ${WHITE}"$1" . . .${NC}"
    xz -dfkv "$1"
}

function get_extracted_file_path {
    echo "$(dirname "$1")/$(basename -s .xz "$1")"
}

function get_device_label {
    local dev="$1"
    local label=$(blkid -o value -s LABEL $dev)
    local uuid=$(blkid -o value -s UUID $dev)

    # this function will return device label
    # or device UUID if label is not set
    if [[ "$label" != "" ]]; then
        echo "$label"
    else
        echo "$uuid"
    fi
}

function guess_and_mount_part {
    local guessed_dev="$1"
    local assigned_mount_dir="$2"
    local device_type=$(blkid -o value -s TYPE "$guessed_dev")

    if [[ "$device_type" == "vfat" ]]; then
        # This is a boot partition
        # We set the global $MOUNTED_BOOT_PART
        echo -e "${LBLUE}Device ${WHITE}$guessed_dev${LBLUE} is a ${YELLOW}boot${LBLUE} partition${NC}"
        echo -e "${LBLUE}Creating directory ${WHITE}$assigned_mount_dir${NC}"
        mkdir -p "$assigned_mount_dir"

        echo -e "${LBLUE}Assigning ${LGREEN}$guessed_dev${LBLUE} to ${WHITE}$assigned_mount_dir${LBLUE}${NC}"
        mount "$guessed_dev" "$assigned_mount_dir"

        MOUNTED_BOOT_PART="$assigned_mount_dir"
        MOUNT_DIR_ARRAY+=("$assigned_mount_dir")
    elif [[ "$device_type" == "ext4" ]]; then
        # This is a root partition
        # We set the global $MOUNTED_ROOT_PART
        echo -e "${LBLUE}Device ${WHITE}$guessed_dev${LBLUE} is a ${YELLOW}root${LBLUE} partition${NC}"
        echo -e "${LBLUE}Creating directory ${WHITE}$assigned_mount_dir${NC}"
        mkdir -p "$assigned_mount_dir"
        
        echo -e "${LBLUE}Assigning ${LGREEN}$guessed_dev${LBLUE} to ${WHITE}$assigned_mount_dir${LBLUE}${NC}"
        mount "$guessed_dev" "$assigned_mount_dir"

        MOUNTED_ROOT_PART="$assigned_mount_dir"
        MOUNT_DIR_ARRAY+=("$assigned_mount_dir")
    else
        # This neither boot or root partition
        echo -e "${LBLUE}Device ${WHITE}$guessed_dev${LBLUE} is neither ${YELLOW}boot${LBLUE} or ${YELLOW}root${LBLUE} partition${NC}"
    fi
}

function get_root_loop_partition {
    for ((idx=0; idx<${#LOOP_DEVICES[@]}; ++idx)); do
        local type=$(blkid -o value -s TYPE /dev/mapper/${LOOP_DEVICES[idx]})

        if [[ "$type" == "ext4" ]]; then
            echo "${LOOP_DEVICES[idx]}"
            break
        fi
    done
}

function map_and_get_loop_devices {
    kpartx -av "$1" | grep "loop" | awk -F" " '{print $3}'
}

function map_and_mount_devices {
    for ((idx=0; idx<${#LOOP_DEVICES[@]}; ++idx)); do
        local dev_label=$(get_device_label /dev/mapper/${LOOP_DEVICES[idx]})

        echo -e "${LBLUE}Guessing ${WHITE}/dev/mapper/${LOOP_DEVICES[idx]} ${LBLUE}partition type${NC}"
        guess_and_mount_part "/dev/mapper/${LOOP_DEVICES[idx]}" "$MOUNT_PARENT/$dev_label"
    done
}

function calculate_fs_size {
    local directory="$1"
    local percent_margin=10     # 10% margin of free space
    size="$(df --output=size "$directory" | tail -n1)"

    # we add a bit margin of free space to the designated temporary drive target
    size=$((($size * $percent_margin / 100) + $size))

    echo $size
}

function create_and_mount_temporary_f2fs_drive {
    local size="$1"
    dd if=/dev/zero of="$TEMP_FS_FILE" bs=2k count=$size
    mkfs.f2fs "$TEMP_FS_FILE"
    mkdir -p "$MOUNTED_TMP_PART"
    mount "$TEMP_FS_FILE" "$MOUNTED_TMP_PART"
}

function backup_root_content {
    rsync -ax --progress --inplace "$MOUNTED_ROOT_PART/." "$MOUNTED_TMP_PART"
}

function format_root_as_f2fs {
    local loop="$1"
    
    echo -e "${LRED}Formatting live image root partition as F2FS . . . ${NC}"
    umount "$MOUNTED_ROOT_PART"
    wipefs -a "/dev/mapper/$loop"
    mkfs.f2fs "/dev/mapper/$loop"
}

function patch_system_file {
    local loop="$1"

    # get fstab settings for root partition
    FSTAB_ROOT_ENTRY=$(cat $MOUNTED_TMP_PART/etc/fstab | grep "ext4")
    FSTAB_CURR_ROOT_ID=$(awk -F' ' '{print $1}' <<< $FSTAB_ROOT_ENTRY)

    # start patching fstab root entry line
    if [[ "$FSTAB_CURR_ROOT_ID" == *"PART"* ]]; then
        # if the fstab entry using PARTUUID as identifier, we use it as well
        echo -e "${LBLUE}Patching fstab PARTUUID data . . .${NC}"
        FSTAB_NEW_ROOT_ID_VALUE=$(blkid -o value -s PARTUUID /dev/mapper/$loop)
        FSTAB_NEW_ROOT_ID="PARTUUID=$FSTAB_NEW_ROOT_ID_VALUE"
    else
        # the fstab entry not using PARTUUID, probably using UUID
        echo -e "${LBLUE}Patching fstab UUID data . . .${NC}"
        FSTAB_NEW_ROOT_ID_VALUE=$(blkid -o value -s UUID /dev/mapper/$loop)
        FSTAB_NEW_ROOT_ID="UUID=$FSTAB_NEW_ROOT_ID_VALUE"
    fi

    FSTAB_ROOT_ENTRY=$(sed -e "s/$FSTAB_CURR_ROOT_ID/$FSTAB_NEW_ROOT_ID/g" <<< $FSTAB_ROOT_ENTRY)

    echo -e "${LBLUE}Patching fstab FS type . . .${NC}"
    FSTAB_ROOT_ENTRY=$(sed -e "s/ext4/f2fs/g" <<< $FSTAB_ROOT_ENTRY)
    
    echo -e "${LBLUE}Patching fstab FS attribute . . .${NC}"
    FSTAB_ROOT_ENTRY=$(sed -e "s/defaults,noatime/defaults,noatime,discard/g" <<< $FSTAB_ROOT_ENTRY)

    echo -e "${LGREEN}Storing patched line to fstab file . . .${NC}"
    sed -i "/.*ext4.*/c $FSTAB_ROOT_ENTRY" $MOUNTED_TMP_PART/etc/fstab

    # get cmdline.txt content
    CMDLINE_ENTRY=$(cat $MOUNTED_BOOT_PART/cmdline.txt)

    echo -e "${LBLUE}Patching cmdline.txt root identifier . . .${NC}"
    CMDLINE_CURR_ROOT_ID=$(echo $CMDLINE_ENTRY | awk -F'root=' '{print $2}' | awk -F' ' '{print $1}')

    # seems that AlmaLinux (and possibly RaspberryPi OS?) can only boot
    # from PARTUUID identifier, so we need to set different identifer
    # value for cmdline.txt
    CMDLINE_NEW_ROOT_ID_VALUE=$(blkid -o value -s PARTUUID /dev/mapper/$loop)
    CMDLINE_NEW_ROOT_ID="PARTUUID=$CMDLINE_NEW_ROOT_ID_VALUE"
    CMDLINE_ENTRY=$(sed -e "s/$CMDLINE_CURR_ROOT_ID/$CMDLINE_NEW_ROOT_ID/g" <<< $CMDLINE_ENTRY)

    echo -e "${LBLUE}Patching cmdline.txt root FS type . . .${NC}"
    CMDLINE_ENTRY=$(sed -e "s/ext4/f2fs/g" <<< $CMDLINE_ENTRY)

    echo -e "${LGREEN}Storing patched line to cmdline.txt file . . .${NC}"
    sed -i "/.*ext4.*/c $CMDLINE_ENTRY" $MOUNTED_BOOT_PART/cmdline.txt

    # For debugging only. Uncomment lines below if needed.
    # echo "$FSTAB_ROOT_ENTRY"
    # echo "$CMDLINE_ENTRY"
    # read -p "Press enter to continue . . . "
}

function restore_root_content {
    local loop="$1"

    echo -e "${LBLUE}Copy back old root partition content from temporary FS . . . ${NC}"
    mount "/dev/mapper/$loop" "$MOUNTED_ROOT_PART"
    rsync -ax --progress --inplace "$MOUNTED_TMP_PART/." "$MOUNTED_ROOT_PART"
}

function remove_temporary_drive {
    rm -rf "$TEMP_FS_FILE"
}

function unmount_directories {
    for ((idx=0; idx<${#MOUNT_DIR_ARRAY[@]}; ++idx)); do
        echo -e "${YELLOW}Unmounting ${MOUNT_DIR_ARRAY[idx]}${NC}"
        umount "${MOUNT_DIR_ARRAY[idx]}"
    done

    echo -e "${YELLOW}Unmounting $MOUNTED_TMP_PART${NC}"
    umount "$MOUNTED_TMP_PART"
}

function remove_mount_dir {
    echo -e "${YELLOW}Deleting parent mount directory . . .${NC}"
    rm -rf "$MOUNT_PARENT"
}

function delete_loop_devices {
    echo -e "${YELLOW}Deleting loop devices map of ${LGREEN}"$1" . . .${NC}"
    kpartx -dv "$1"
}

function rename_extracted_file {
    local dirname=$(dirname "$1")
    local filename=$(basename "$1")
    local extension="${filename#*.}"
    local filename=$(echo $filename | awk -F".$extension" '{print $1}')

    filename="$filename-f2fs"
    target="$dirname/$filename.$extension"
    mv "$1" "$target"

    echo "$target"
}

function compress_modified_image {
    echo -e "${LBLUE}Compressing patched image . . .${NC}"
    xz -zfv8 "$1"
}

function main {
    sanity_check $@
    install_dependencies

    # If no file specified from argument, then open file dialog to select one
    while [ "$XZ_IMG" == "" ]
    do
        select_file

        if [ "$XZ_IMG" == "" ]; then
            echo -e "${YELLOW}Choose one image file to continue.${NC}"
        fi
    done

    echo -e "${LGREEN}You choose ${WHITE}$XZ_IMG${NC}"
    extract_file "$XZ_IMG"
    
    EXTRACTED_FILE=$(get_extracted_file_path "$XZ_IMG")
    LOOP_DEVICES=( $(map_and_get_loop_devices "$EXTRACTED_FILE") )
    ROOT_LOOP=$(get_root_loop_partition "$EXTRACTED_FILE")
    
    map_and_mount_devices

    FS_SIZE=$(calculate_fs_size "$MOUNTED_ROOT_PART")

    create_and_mount_temporary_f2fs_drive "$FS_SIZE"
    backup_root_content

    echo -e "${YELLOW}The live image content was backed up and ready to be formatted.${NC}"

    # Uncomment this line of needed
    # read -p "Press Enter to continue . . ."

    # Do the heavy-lifting
    format_root_as_f2fs "$ROOT_LOOP"
    patch_system_file "$ROOT_LOOP"
    restore_root_content "$ROOT_LOOP"

    echo -e "${LGREEN}The live image content was restored.${NC}"

    # Uncomment this line of needed
    # read -p "Press Enter to continue . . ."

    # Cleanup
    unmount_directories
    delete_loop_devices "$EXTRACTED_FILE"
    remove_mount_dir
    remove_temporary_drive

    # Compress the patched and converted image
    PATCHED_FILE=$(rename_extracted_file "$EXTRACTED_FILE")
    compress_modified_image "$PATCHED_FILE"

    echo -e "${LGREEN}Done converting image.${NC}"
    echo -e "${LGREEN}The patched image is ${WHITE}${PATCHED_FILE}.xz${NC}"

    # The code below didn't work
    # echo -e '#!/bin/bash\nxdg-open "'$(dirname "$PATCHED_FILE")'"' > /tmp/open.sh
    # runuser -l $(logname) -c 'bash /tmp/open.sh'
    # rm -rf /tmp/open.sh
}

main $@
