#!/bin/bash

# =====================================================================
# rpif2fs.sh : Universal Multi-Distro Live Image Converter for Raspberry Pi
# =====================================================================
# Description       : Concurrently converts official Raspberry Pi Ext4/XFS OS images 
#                     to optimized F2FS layouts. Features dynamic runtime feature
#                     detection supporting both Dracut (RHEL/Alma/Rocky/Fedora) and
#                     Initramfs-Tools (Debian/Ubuntu/Raspberry Pi OS) frameworks.
#                     Optimized logging pipeline structure via direct file descriptor
#                     mapping channels to ensure structural older-shell compatibility.
# Style Standard    : Google Bash Scripting Guide & Defensive Engineering
# Usage             : sudo bash rpif2fs.sh ["/path/to/image.img.xz"]
# Author            : David Eleazar
# Year              : 2024-2026
# =====================================================================

# Enforce strict pipeline failure propagation to stop early if any command in a pipe fails
set -o pipefail

# --- ANSI Terminal Functional Color Escape Sequences (Read-Only Constants) ---
readonly COLOR_NC='\033[0m'             # No Color / Reset terminal graphics context
readonly COLOR_RED='\033[0;31m'         # Red color for critical error notifications
readonly COLOR_GREEN='\033[0;32m'       # Green color for success checkpoint messages
readonly COLOR_YELLOW='\033[0;33m'      # Yellow color for warnings or stagger alerts
readonly COLOR_LBLUE='\033[1;34m'       # Light Blue color for structural phase updates
readonly COLOR_WHITE='\033[1;37m'       # Bold White color for highlighted string variables

# --- Runtime Variable Trackers (Google Style Guide Lowercase Compliance) ---
loop_devices=()                         # Dynamic array tracking active device-mapper partition nodes
mount_dir_array=()                      # LIFO tracking array containing mounted paths for clean rollbacks
xz_img=""                               # Absolute file path referencing the source compressed archive (.xz)
extracted_file=""                       # Path pointing to the decompressed raw storage payload image
patched_file=""                         # Final distribution destination path after transformation processing
mounted_boot_part=""                    # Workspace mount point assigned to the VFAT/MSDOS partition layout
mounted_root_part=""                    # Workspace mount point assigned to the native root image filesystem
image_base=""                           # Normalized image filename string stripped of extensions for lock paths
lock_file_path=""                       # Mutual exclusion path preventing race conditions on duplicate files
mount_parent=""                         # Isolated parent workspace path encapsulated using active PID ($$)
temp_fs_file="/var/tmp/rpif2_${$}.fs"   # Temporary block data asset file mapped into intermediate translation
mounted_tmp_part=""                     # Mount directory boundary pointing to the translation storage payload
log_file=""                             # Destination file path mirroring stdout/stderr without ANSI tokens
staging_framework="none"                # Profile identifier for target initramfs manager (dracut/initramfs-tools)
root_loop_dev_node=""                   # Specific loop block device pointing natively to the system true root
install_lvm2=""                         # Conditional storage driver injection package label for enterprise systems
start_time=0                            # Benchmark tracking execution entry anchor
end_time=0                              # Benchmark tracking execution finish anchor

# =====================================================================
# Function    : sanity_check
# Description : Verifies that the script is executed with root privileges,
#               which is mandatory for raw block mapping and chroot executions.
# Arguments   : None
# =====================================================================
sanity_check() {
    # Announce the execution of host environment verification tests
    echo -e "${COLOR_LBLUE}Sanity checking environment . . .${COLOR_NC}"

    # Evaluate effective user identity; non-zero value indicates lack of administrative access
    if [[ "$(id -u)" != "0" ]]; then
        # Print standardized command interface usage layout instructions
        echo -e "${COLOR_WHITE}Usage: sudo bash rpif2fs.sh [/path/to/image.img.xz]${COLOR_NC}"
        # Provide additional context on interactive user-interface fallback behaviors
        echo "Where the image path argument is optional (will fallback to GUI selection if empty)."
        # Separate standard message context from the terminal error announcement
        echo -e "_____"
        # Display the missing privilege error notification using the designated error color block
        echo -e "${COLOR_RED}ERROR: Root access denied. Please run as root (sudo).${COLOR_NC}"
        # Exit immediately with status code 1 to signal a fatal configuration block
        exit 1
    fi

    # Log successful validation indicating that current process execution context is correct
    echo -e "${COLOR_GREEN}Environment is sane.${COLOR_NC}"
}

# =====================================================================
# Function    : install_dependencies
# Description : Automates host-side toolchain provisioning by mapping
#               required binaries across different standard package managers.
# Arguments   : None
# =====================================================================
install_dependencies() {
    # Announce package validation phase across active package repositories
    echo -e "${COLOR_LBLUE}Probing and verifying host system dependencies . . .${COLOR_NC}"
    # Initialize an empty array context tracking dependencies absent from host system
    local missing_pkgs=()
    # Establish package manager scope variable binding
    local package_manager=""

    # Heuristically detect package manager binary signature via command lookup paths
    if [[ -n "$(command -v dnf 2>/dev/null)" ]]; then
        package_manager="dnf"        # Bind toolchain deployment commands to modern DNF framework
    elif [[ -n "$(command -v yum 2>/dev/null)" ]]; then
        package_manager="yum"        # Bind toolchain deployment commands to legacy YUM framework
    elif [[ -n "$(command -v apt 2>/dev/null)" ]]; then
        package_manager="apt"        # Bind toolchain deployment commands to Debian APT framework
    else
        # Throw fatal error if no known compatible distribution manager context is identified
        echo -e "${COLOR_RED}ERROR: No supported package manager (apt/dnf/yum) found on host system!${COLOR_NC}"
        # Abort operation context because missing utilities cannot be deployed automatically
        exit 1
    fi

    # Verify presence of XZ decompression architecture, mapping package naming variations safely
    if ! command -v xz >/dev/null 2>&1; then
        [[ "${package_manager}" == "apt" ]] && missing_pkgs+=("xz-utils") || missing_pkgs+=("xz")
    fi
    # Verify presence of F2FS backend filesystem building utility toolchains
    if ! command -v mkfs.f2fs >/dev/null 2>&1; then
        missing_pkgs+=("f2fs-tools")
    fi
    # Verify presence of kpartx sector mapping block allocation handlers
    if ! command -v kpartx >/dev/null 2>&1; then
        missing_pkgs+=("kpartx")
    fi
    # Verify presence of Logical Volume Management control facilities
    if ! command -v vgchange >/dev/null 2>&1; then
        missing_pkgs+=("lvm2")
    fi
    # Verify presence of recursive synchronization rsync mirroring toolchains
    if ! command -v rsync >/dev/null 2>&1; then
        missing_pkgs+=("rsync")
    fi

    # Verify presence of cross-architecture user-space emulation layer bridges (Only if host is NOT ARM64)
    if [[ "$(uname -m)" != "aarch64" && "$(uname -m)" != "arm64" ]]; then
        if [[ ! -f "/usr/bin/qemu-aarch64-static" ]] && [[ ! -f "/usr/libexec/qemu-binfmt/aarch64-binfmt-static" ]]; then
            missing_pkgs+=("qemu-user-static")
        fi
    fi

    # Evaluate array length; if zero, all necessary utilities exist on host machine
    if [[ "${#missing_pkgs[@]}" -eq 0 ]]; then
        # Inform user that host state satisfies all prerequisite constraints
        echo -e "${COLOR_GREEN}All required host dependencies are satisfied and active.${COLOR_NC}"
        # Return success status code 0 to transition to primary deployment stages
        return 0
    fi

    # Inform user about missing binaries detected on the active platform
    echo -e "${COLOR_YELLOW}Missing host tools detected: [${missing_pkgs[*]}]. Installing...${COLOR_NC}"
    # Fork package deployment execution path targeting Debian-family distributions
    if [[ "${package_manager}" == "apt" ]]; then
        # Synchronize repository indexes and deploy missing entries non-interactively
        apt-get update -y && apt-get install -y "${missing_pkgs[@]}"
    else
        # Deploy missing entries via RedHat-family management wrappers non-interactively
        "${package_manager}" install -y "${missing_pkgs[@]}"
    fi
    # Log resolution confirmation indicating prerequisite libraries are active
    echo -e "${COLOR_GREEN}Host tools successfully initialized.${COLOR_NC}"
}

# =====================================================================
# Function    : initialize_instance_paths
# Description : Constructs isolated operational boundaries utilizing the PID ($$).
# Arguments   : $1 - Absolute target file path
# =====================================================================
initialize_instance_paths() {
    # Extract absolute target reference variable from position argument binding
    local raw_file="${1}"
    
    # Strip parent directories and capture base string tokens up to the first extension marker
    image_base=$(basename "${raw_file}" .xz)
    # Define atomic lock path using unique text tokens to shield concurrent modifications
    lock_file_path="/var/run/rpif2fs_${image_base}.lock"
    # Construct master tracking directory isolated from other running process PIDs
    mount_parent="/mnt/rpif2fs_${$}"
    # Formulate temporary loop container filesystem path under virtual allocation space
    temp_fs_file="/var/tmp/rpif2_${$}.fs"
    # Establish local mount path pointing to the translation folder target boundary
    mounted_tmp_part="${mount_parent}/tmp"
    
    # Generate structural logs directory context safely within the current shell directory
    mkdir -p "$(pwd)/logs"
    # Map the finalized conversion log output destination straight into logs directory
    log_file="$(pwd)/logs/rpif2fs_${image_base}_conversion.log"
}

# =====================================================================
# Function    : acquire_lock
# Description : Enforces IPC transaction locking to prevent running multiple
#               conversion instances on the exact same target image.
# Arguments   : None
# =====================================================================
acquire_lock() {
    # Initialize process identifier verification string track
    local active_pid=""
    
    # Check if a process transaction file footprint already exists for this image asset
    if [[ -e "${lock_file_path}" ]]; then
        # Extract process identification token from the active lockfile path
        active_pid="$(cat "${lock_file_path}" 2>/dev/null)"
        # Confirm if captured token maps directly to a truly running process state
        if [[ -n "${active_pid}" ]] && kill -0 "${active_pid}" 2>/dev/null; then
            # Print critical concurrency collision notification to the standard out channel
            echo -e "${COLOR_RED}CRITICAL CONCURRENCY ERROR: Target image [${image_base}] is already being processed!${COLOR_NC}"
            # State block constraints noting the conflicting process identifier metadata
            echo -e "${COLOR_RED}Blocked execution assignment targeting active process PID: ${COLOR_WHITE}${active_pid}${COLOR_NC}"
            # Halt script thread operation immediately with code 1 to protect current file states
            exit 1
        fi
        # Warn user about stale lockfile traces and signal intentional override pathing
        echo -e "${COLOR_YELLOW}Warning: Found a stale lockfile footprint for this image. Overwriting...${COLOR_NC}"
    fi
    # Commit the active thread identity code directly to the lock destination target
    echo "$$" > "${lock_file_path}"
}

# =====================================================================
# Function    : remove_lock
# Description : Safely deletes the file lock to unlock future script operations.
# Arguments   : None
# =====================================================================
remove_lock() {
    # Erase the transactional lock track file if it physically exists on the disk layout
    [[ -f "${lock_file_path}" ]] && rm -f "${lock_file_path}"
}

# =====================================================================
# Function    : select_file
# Description : Activates visual GUI fallbacks (Zenity or KDialog).
# Arguments   : None
# =====================================================================
select_file() {
    # Establish structural home path tracking variable
    local home_dir=""
    # Retrieve true home path data string directly from user accounting databases
    home_dir="$(getent passwd "$(logname)" | cut -d: -f6)"
    
    # Interrogate path locations for native KDE widget display interfaces
    if [[ -n "$(command -v kdialog 2>/dev/null)" ]]; then
        # Render open file prompt selector bounded to compression file extension criteria
        xz_img="$(kdialog --title="Choose Live Image File" --getopenfilename "${home_dir}" '*.xz')"
    else
        # Fallback to generic GNOME/GTK toolkit file chooser graphical layouts
        xz_img="$(zenity --file-selection --title="Choose Live Image File" --filename="${home_dir}")"  
    fi
}

# =====================================================================
# Function    : extract_file
# Description : Losslessly decompresses the targeted system archive using 2 threads.
# Arguments   : $1 - Archive target path
# =====================================================================
extract_file() {
    # Log active decompression stage tracking metrics mapping process identity context
    echo -e "${COLOR_LBLUE}[PID: ${$}] Decompressing image payload asset: ${COLOR_WHITE}${1}${COLOR_NC}"
    # Unpack file using 2 threads while conserving source container state
    xz -dfkv -T2 "${1}"
}

# =====================================================================
# Function    : get_extracted_file_path
# Description : Resolves target extraction bounds by stripping compression tokens.
# Arguments   : $1 - Archive target path
# =====================================================================
get_extracted_file_path() {
    # Evaluate normalized directory target bounds and strip archive extension suffix
    echo "$(dirname "${1}")/$(basename -s .xz "${1}")"
}

# =====================================================================
# Function    : map_and_get_loop_devices
# Description : Employs kpartx to physically map the raw storage payload.
# Arguments   : $1 - Raw image file string
# =====================================================================
map_and_get_loop_devices() {
    # Bind incoming filesystem data string argument
    local raw_img="${1}"
    # Target execution return stream memory log hook
    local kpartx_output
    # Construct temporary line grouping buffer track array
    local lines=()
    # Construct loop channel target node buffer track array
    local loop_nodes=()

    # Activate kpartx mapping nodes adding loops aggressively and capturing standard output streams
    kpartx_output=$(kpartx -av "${raw_img}")
    # Handle block parsing execution exceptions immediately upon error return signatures
    if [[ $? -ne 0 ]]; then
        # Direct structural exception descriptions to standard error stream paths
        echo "ERROR: kpartx execution failed mapping raw image blocks." >&2
        # Drop out of execution context immediately to intercept corrupted array mappings
        exit 1
    fi

    # Read the returned device map logging streams line by line into string arrays
    while read -r line; do
        # Evaluate line characters; verify element length boundary constraint is non-zero
        if [[ -n "${line}" ]]; then
            # Stack the string trace reference directly into local execution array maps
            lines+=("${line}")
        fi
    done <<< "${kpartx_output}"

    # Sweep through captured device map allocation confirmation traces
    for line in "${lines[@]}"; do
        # Detect target layout identifiers reporting loop creation or structural device additions
        if echo "${line}" | grep -q -E 'add fastboot|add map'; then
            # Isolate third word token mapping directly to loop node descriptor naming maps
            local mapper_node
            mapper_node=$(echo "${line}" | awk '{print $3}')
            # Validate extracted node token boundary lengths before queuing assignments
            if [[ -n "${mapper_node}" ]]; then
                # Queue device mapper identity label string directly into deployment tracking arrays
                loop_nodes+=("${mapper_node}")
            fi
        fi
    done

    # Intercept zero length array exceptions indicating execution environment parsing failures
    if [[ ${#loop_nodes[@]} -eq 0 ]]; then
        # Route device mapping error data down to system standard error descriptors
        echo "ERROR: Failed to capture valid loop mapping channels from kpartx." >&2
        # Abort runtime pipeline context to block downstream logic errors
        exit 1
    fi

    # Print out space-separated loop device mappings safely into standard string captures
    echo "${loop_nodes[@]}"
}

# =====================================================================
# Function    : scan_and_mount_system_layout
# Description : Core heuristics engine. Evaluates mapped device blkid tags and fstab roots.
# Arguments   : None
# =====================================================================
scan_and_mount_system_layout() {
    # Initialize active device iteration tracker string
    local dev_name=""
    # Initialize physical node absolute address loop tracker string
    local dev_path=""
    # Initialize target filesystem block signature capture identifier
    local fstype=""
    # Define safe transient file location boundary mapping to isolate probing sequences
    local probe_dir="/tmp/rpif2_probe_${$}"
    
    # Construct target transient exploratory mount point location directory safely
    mkdir -p "${probe_dir}"

    # Confirm if logical volume mapping services are deployed on the host system
    if command -v vgchange >/dev/null 2>&1; then
        # Force activation of latent volume groups located within loop block structures
        vgchange -ay > /dev/null 2>&1
    fi

    # Iterate structural device mapper layout entries discovered during initialization routines
    for dev_name in "${loop_devices[@]}"; do
        # Formulate absolute block hardware node path binding under mapper directory lines
        dev_path="/dev/mapper/${dev_name}"
        # Interrogate target layout signature maps for hardware filesystem definitions
        fstype="$(blkid -o value -s TYPE "${dev_path}" 2>/dev/null)"

        # Intercept virtual allocation tables indicating boot loading data components
        if [[ "${fstype}" == "vfat" ]] || [[ "${fstype}" == "msdos" ]]; then
            # Establish localized target layout tracking variables for boot loading folder mounts
            local mnt_boot="${mount_parent}/boot"
            # Announce hardware block assignment identification metrics to the main terminal out channel
            echo -e "${COLOR_LBLUE}[PID: ${$}] Device ${COLOR_WHITE}${dev_path}${COLOR_LBLUE} is identified as a ${COLOR_YELLOW}boot${COLOR_LBLUE} partition${COLOR_NC}"
            # Construct execution workspace layout folder targets safely on host disk structures
            mkdir -p "${mnt_boot}"
            # Attach hardware physical layout maps directly onto the boot staging directory tree
            mount "${dev_path}" "${mnt_boot}"
            # Bind absolute active boot folder mapping tracking attributes into global storage trackers
            mounted_boot_part="${mnt_boot}"
            # Stack path reference onto runtime array layouts to ensure robust teardown execution
            mount_dir_array+=("${mnt_boot}")
        # Detect primary base system partitions using signature lookup mappings
        elif [[ "${fstype}" == "ext4" ]] || [[ "${fstype}" == "xfs" ]]; then
            # Bind block geometry read-only onto temporary evaluation points to check structure files
            mount -o ro "${dev_path}" "${probe_dir}" 2>/dev/null
            # Confirm if file allocation matrix houses genuine system partition indicators
            if [[ -f "${probe_dir}/etc/fstab" ]]; then
                # Log system verification confirmation metric details straight to output log files
                echo -e "${COLOR_GREEN}[PID: ${$}] Device ${COLOR_WHITE}${dev_path}${COLOR_GREEN} is successfully verified as the TRUE ROOT partition${COLOR_NC}"
                # Unmount transient testing hooks cleanly before transitioning to production layout paths
                umount "${probe_dir}"
                # Define baseline location folder mappings to allocate active root system layers
                local mnt_root="${mount_parent}/root"
                # Construct target destination framework folders recursively on host platform layout
                mkdir -p "${mnt_root}"
                # Bind live root blocks directly onto operational execution directory trees
                mount "${dev_path}" "${mnt_root}"
                # Update absolute global instance path track values to preserve root target pointers
                mounted_root_part="${mnt_root}"
                # Queue folder tracking parameters into runtime execution teardown maps
                mount_dir_array+=("${mnt_root}")
                # Record specific loop identity token values mapping to the discovered true system root
                root_loop_dev_node="${dev_name}"
            else
                # Disconnect exploratory partition loops if verification files are absent
                umount "${probe_dir}" 2>/dev/null
                # Establish recovery paths routing auxiliary partition maps down onto storage slots
                local mnt_aux="${mount_parent}/aux_boot"
                # Construct workspace slots recursively on target host hardware disk spaces
                mkdir -p "${mnt_aux}"
                # Connect unverified data clusters down onto structural auxiliary staging boundaries
                mount "${dev_path}" "${mnt_aux}"
                # Push active mount point assignments directly into LIFO allocation trackers
                mount_dir_array+=("${mnt_aux}")
            fi
        fi
    done

    if [[ -z "${mounted_root_part}" ]]; then
        # Inform user about root partition absences and activate low-level logical volume scanner
        echo -e "${COLOR_YELLOW}[PID: ${$}] Root partition not found in raw blocks. Sweeping active LVM Logical Volumes...${COLOR_NC}"
        local lv_node=""
        for lv_node in /dev/mapper/*; do
            if [[ "${lv_node}" == *control* ]] || [[ "${lv_node}" == *loop* ]]; then
                continue
            fi
            if [[ -b "${lv_node}" ]]; then
                fstype="$(blkid -o value -s TYPE "${lv_node}" 2>/dev/null)"
                if [[ "${fstype}" == "ext4" ]] || [[ "${fstype}" == "xfs" ]]; then
                    mount -o ro "${lv_node}" "${probe_dir}" 2>/dev/null
                    if [[ -f "${probe_dir}/etc/fstab" ]]; then
                        echo -e "${COLOR_GREEN}[PID: ${$}] Found LVM target: ${COLOR_WHITE}${lv_node}${COLOR_GREEN} verified as TRUE ROOT filesystem${COLOR_NC}"
                        umount "${probe_dir}"
                        local mnt_root="${mount_parent}/root"
                        mkdir -p "${mnt_root}"
                        mount "${lv_node}" "${mnt_root}"
                        mounted_root_part="${mnt_root}"
                        mount_dir_array+=("${mnt_root}")
                        root_loop_dev_node="$(basename "${lv_node}")"
                        install_lvm2="lvm2"
                        break
                    else
                        umount "${probe_dir}"
                    fi
                fi
            fi
        done
    fi

    rm -rf "${probe_dir}"
    
    if [[ -z "${mounted_root_part}" ]]; then
        echo -e "${COLOR_RED}CRITICAL STRUCTURAL ERROR: Failed to isolate system true root partition configuration context!${COLOR_NC}"
        exit 1
    fi
}

# =====================================================================
# Function    : calculate_fs_size
# Description : Determines intermediate sizing dimensions injecting a 15% growth pad.
# Arguments   : $1 - Staging directory reference target
# =====================================================================
calculate_fs_size() {
    local directory="${1}"
    local percent_margin=15     
    local size=0
    size="$(df --output=size "${directory}" | tail -n1)"
    size=$(( (size * percent_margin / 100) + size ))
    echo "${size}"
}

# =====================================================================
# Function    : create_and_mount_temporary_f2fs_drive
# Description : Allocates intermediate loop drives mimicking final structural payloads.
# Arguments   : $1 - Desired drive blocks footprint size
# =====================================================================
create_and_mount_temporary_f2fs_drive() {
    local size="${1}"
    dd if=/dev/zero of="${temp_fs_file}" bs=1k count="${size}"
    mkfs.f2fs -f -O extra_attr,inode_checksum,sb_checksum,compression "${temp_fs_file}" > /dev/null
    mkdir -p "${mounted_tmp_part}"
    mount "${temp_fs_file}" "${mounted_tmp_part}"
}

# =====================================================================
# Function    : mount_chroot_pseudo_filesystems
# Description : Binds host interfaces (/dev, /proc) into staging root boundaries
#               and explicitly enforces private mount propagation to prevent
#               lazy unmounts from bleeding back into the host OS namespace.
# Arguments   : None
# =====================================================================
mount_chroot_pseudo_filesystems() {
    echo -e "${COLOR_LBLUE}[PID: ${$}] Mounting core host pseudo-filesystems into chroot staging area . . .${COLOR_NC}"
    local dir=""

    for dir in dev dev/pts proc sys run; do
        mkdir -p "${mounted_tmp_part}/${dir}"
        
        if mount --bind "/${dir}" "${mounted_tmp_part}/${dir}" 2>/dev/null; then
            mount --make-private "${mounted_tmp_part}/${dir}" 2>/dev/null
        fi
    done
}

# =====================================================================
# Function    : backup_root_content
# Description : Synchronizes content to F2FS payload via recursive rsync arrays.
# Arguments   : None
# =====================================================================
backup_root_content() {
    echo -e "${COLOR_LBLUE}[PID: ${$}] Backing up root content to temporary F2FS staging area . . .${COLOR_NC}"
    rsync -axHAX --info=progress2 --inplace --filter="-x security.selinux*" "${mounted_root_part}/." "${mounted_tmp_part}"
}

# =====================================================================
# Function    : format_root_as_f2fs
# Description : Destroys previous ext4 superblock maps and forces F2FS geometry.
# Arguments   : $1 - Loop device mapper target
# =====================================================================
format_root_as_f2fs() {
    local loop="${1}"
    echo -e "${COLOR_RED}[PID: ${$}] Wiping and formatting native image root partition to F2FS layout . . . ${COLOR_NC}"
    umount -fl "${mounted_root_part}" 2>/dev/null || true
    wipefs -a "/dev/mapper/${loop}"
    mkfs.f2fs -f "/dev/mapper/${loop}"
}

# =====================================================================
# Function    : patch_system_file
# Description : Patches OS configuration files (fstab, cmdline, BLS entries).
#               Injects an early-boot transient Systemd service to revert
#               SELinux to Enforcing mode before cloud-init executes a reboot,
#               resolving first-boot race conditions.
# Arguments   : $1 - Target root loop device node name
# =====================================================================
patch_system_file() {
    local loop="${1}"
    local fstab_root_entry=""
    local fstab_curr_root_id=""
    local fstab_new_root_id_value=""
    local fstab_new_root_id=""
    local current_fstype=""
    local current_options=""
    local cmdline_entry=""
    local cmdline_curr_root_id=""
    local cmdline_new_root_id=""
    local curr_rootfstype=""

    # Extract active filesystem block paths and current formatting values
    fstab_root_entry="$(awk '$2 == "/" {print $0}' "${mounted_tmp_part}/etc/fstab")"
    fstab_curr_root_id="$(awk '$2 == "/" {print $1}' "${mounted_tmp_part}/etc/fstab")"
    current_fstype="$(awk '$2 == "/" {print $3}' "${mounted_tmp_part}/etc/fstab")"
    current_options="$(awk '$2 == "/" {print $4}' "${mounted_tmp_part}/etc/fstab")"

    # Defensively intercept structural absences of root entries inside the fstab table
    if [[ -z "${fstab_root_entry}" ]]; then
        echo -e "${COLOR_YELLOW}[PID: ${$}] Warning: Root entry (/) not found in staging fstab file.${COLOR_NC}"
        return 0
    fi

    # Rewrite fstab block identifiers mapping either PARTUUID or UUID signatures cleanly
    if [[ "${fstab_curr_root_id}" == *"PARTUUID"* ]]; then
        fstab_new_root_id_value="$(blkid -o value -s PARTUUID "/dev/mapper/${loop}" 2>/dev/null || blkid -o value -s PARTUUID "/dev/${loop}")"
        fstab_new_root_id="PARTUUID=${fstab_new_root_id_value}"
        fstab_root_entry="$(sed -e "s|${fstab_curr_root_id}|${fstab_new_root_id}|g" <<< "${fstab_root_entry}")"
    elif [[ "${fstab_curr_root_id}" == *"UUID"* ]]; then
        fstab_new_root_id_value="$(blkid -o value -s UUID "/dev/mapper/${loop}" 2>/dev/null || blkid -o value -s UUID "/dev/${loop}")"
        fstab_new_root_id="UUID=${fstab_new_root_id_value}"
        fstab_root_entry="$(sed -e "s|${fstab_curr_root_id}|${fstab_new_root_id}|g" <<< "${fstab_root_entry}")"
    fi

    # Modify filesystem indicators to target F2FS parameters natively
    fstab_root_entry="$(sed -e "s/[[:space:]]${current_fstype}[[:space:]]/ f2fs /g" <<< "${fstab_root_entry}")"
    fstab_root_entry="$(sed -e "s|${current_options}|defaults,noatime,discard|g" <<< "${fstab_root_entry}")"

    echo -e "${COLOR_GREEN}[PID: ${$}] Committing updated root configuration line to staging fstab . . .${COLOR_NC}"
    awk -v r="${fstab_root_entry}" '$2 == "/" {$0 = r} {print}' "${mounted_tmp_part}/etc/fstab" > "${mounted_tmp_part}/etc/fstab.tmp"
    mv "${mounted_tmp_part}/etc/fstab.tmp" "${mounted_tmp_part}/etc/fstab"

    # Patch secondary standard kernel parameters for bootloaders if physically present
    if [[ -f "${mounted_boot_part}/cmdline.txt" ]]; then
        cmdline_entry="$(cat "${mounted_boot_part}/cmdline.txt")"
        cmdline_curr_root_id="$(echo "${cmdline_entry}" | grep -o -E 'root=[^[:space:]]+' | cut -d= -f2-)"

        if [[ "${cmdline_curr_root_id}" == *"PARTUUID"* ]]; then
            cmdline_new_root_id="PARTUUID=$(blkid -o value -s PARTUUID "/dev/mapper/${loop}" 2>/dev/null || blkid -o value -s PARTUUID "/dev/${loop}")"
        elif [[ "${cmdline_curr_root_id}" == *"UUID"* ]]; then
            cmdline_new_root_id="UUID=$(blkid -o value -s UUID "/dev/mapper/${loop}" 2>/dev/null || blkid -o value -s UUID "/dev/${loop}")"
        else
            cmdline_new_root_id="${cmdline_curr_root_id}"
        fi
        
        cmdline_entry="$(sed -e "s|root=${cmdline_curr_root_id}|root=${cmdline_new_root_id}|g" <<< "${cmdline_entry}")"
        
        if [[ "${cmdline_entry}" == *"rootfstype="* ]]; then
            curr_rootfstype="$(echo "${cmdline_entry}" | grep -o -E 'rootfstype=[^[:space:]]+' | cut -d= -f2-)"
            cmdline_entry="$(sed -e "s|rootfstype=${curr_rootfstype}|rootfstype=f2fs|g" <<< "${cmdline_entry}")"
        else
            cmdline_entry="${cmdline_entry} rootfstype=f2fs"
        fi
        echo "${cmdline_entry}" > "${mounted_boot_part}/cmdline.txt"
    fi

    local bls_entry=""
    local new_bls_uuid=""
    local new_bls_root_string=""

    # Update unified boot loader specification (BLS) configurations for modern platforms
    if [[ -d "${mounted_tmp_part}/boot/loader/entries" ]]; then
        echo -e "${COLOR_YELLOW}[PID: ${$}] Modern BLS target framework detected. Patching GRUB2 kernel options...${COLOR_NC}"
        
        new_bls_uuid="$(blkid -o value -s UUID "/dev/mapper/${loop}" 2>/dev/null || blkid -o value -s UUID "/dev/${loop}")"
        new_bls_root_string="root=UUID=${new_bls_uuid}"

        for bls_entry in "${mounted_tmp_part}/boot/loader/entries"/*.conf; do
            if [[ -f "${bls_entry}" ]]; then
                sed -i -E "s|root=UUID=[^[:space:]]+|${new_bls_root_string}|g" "${bls_entry}"
                sed -i -E "s|root=PARTUUID=[^[:space:]]+|${new_bls_root_string}|g" "${bls_entry}"
                sed -i 's/rootflags=subvol=[^[:space:]]\+//g' "${bls_entry}"
                
                if grep -q "rootfstype=" "${bls_entry}"; then
                    sed -i 's/rootfstype=[^[:space:]]\+/rootfstype=f2fs/g' "${bls_entry}"
                else
                    sed -i '/^options/ s/$/ rootfstype=f2fs/' "${bls_entry}"
                fi
            fi
        done
    fi

    # Handle Enterprise-based distribution security contexts cleanly
    if echo "${image_base}" | grep -q -E -i 'almalinux|fedora|rocky'; then
        if [[ -f "${mounted_tmp_part}/etc/selinux/config" ]]; then
            echo -e "${COLOR_YELLOW}[PID: ${$}] Enterprise Linux detected. Engineering transient SELinux controller...${COLOR_NC}"
            
            # Set initial state to permissive to avoid file labeling blockades during the very first boot execution
            sed -i 's/^SELINUX=.*/SELINUX=permissive/g' "${mounted_tmp_part}/etc/selinux/config"
            
            # Deploy an early-boot one-shot service that reverts the configuration file back to enforcing mode 
            # before cloud-init triggers a system reboot, matching the original image layout cadence.
            local service_path="${mounted_tmp_part}/etc/systemd/system/selinux-re-enforce.service"
            cat << 'EOF' > "${service_path}"
[Unit]
Description=Restore SELinux to Enforcing Mode for Next Boot
DefaultDependencies=no
After=basic.target
Before=cloud-init.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "sed -i 's/^SELINUX=permissive/SELINUX=enforcing/g' /etc/selinux/config && rm -f /etc/systemd/system/basic.target.wants/selinux-re-enforce.service"
RemainAfterExit=yes

[Install]
WantedBy=basic.target
EOF
            chmod 644 "${service_path}"
            
            # Create the early basic target drop-in dependency structures and link the service entry
            mkdir -p "${mounted_tmp_part}/etc/systemd/system/basic.target.wants"
            ln -sf /etc/systemd/system/selinux-re-enforce.service "${mounted_tmp_part}/etc/systemd/system/basic.target.wants/selinux-re-enforce.service"
        fi
    fi

    # Enforce standard system ramdisk loading directives back into hardware profiles
    if [[ -f "${mounted_boot_part}/config.txt" ]]; then
        if [[ "${staging_framework}" == "dracut" ]]; then
            if ! grep -q "initramfs initramfs8" "${mounted_boot_part}/config.txt"; then
                echo -e "\n# Force Dracut Initramfs for custom offline F2FS expansion\ninitramfs initramfs8 followkernel" >> "${mounted_boot_part}/config.txt"
            fi
        else
            if ! grep -q "initramfs initrd.img" "${mounted_boot_part}/config.txt"; then
                echo -e "\n# Force Debian Initramfs for custom offline F2FS expansion\ninitramfs initrd.img followkernel" >> "${mounted_boot_part}/config.txt"
            fi
        fi
    fi
}

# =====================================================================
# Function    : restore_root_content
# Description : Reverse synchronization pushing mapped payloads onto base hardware blocks.
# Arguments   : $1 - Extracted physical map device descriptor loop
# =====================================================================
restore_root_content() {
    local loop="${1}"
    echo -e "${COLOR_LBLUE}[PID: ${$}] Deploying finalized, self-healed contents down to native F2FS cluster . . . ${COLOR_NC}"
    mount "/dev/mapper/${loop}" "${mounted_root_part}"
    rsync -axHAX --info=progress2 --inplace --filter="-x security.selinux*" "${mounted_tmp_part}/." "${mounted_root_part}"
}

# =====================================================================
# Function    : inject_initramfs_expansion_hook
# Description : Seeds offline filesystem capacity scaling routines directly 
#               into the pre-mount boot pipeline. Standard POSIX flat 
#               heredoc design to ensure absolute immunity against 
#               editor indentation auto-formatting bugs. Uses temporary
#               file buffering to catch 100% of interactive C-binary 
#               outputs without triggering pipeline exit code masking.
# Arguments   : None
# =====================================================================
inject_initramfs_expansion_hook() {
    local hook_script_content
    local module_dir
    local creation_hook_dir
    local live_hook_dir

    # Using flat column-0 alignment for the payload script guarantees 
    # that the generated shebang and execution guards are structurally flawless.
    hook_script_content=$(cat << 'EOF'
#!/bin/sh
# Enforce strict error handling inside the ramdisk environment
set -e

PREREQ=""
prereqs() {
    echo "${PREREQ}"
}
case "${1}" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

# Framework-Specific Logging Isolation for global shell scripts
if [ -d /scripts/local-premount ]; then
    if [ -c /dev/kmsg ]; then
        exec > /dev/kmsg 2>&1
    fi
fi

echo "[F2FS-Expand] Initializing pre-mount offline storage expansion sequence..."
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

if ! type parted >/dev/null 2>&1 || ! type resize.f2fs >/dev/null 2>&1; then
    echo "[F2FS-Expand] CRITICAL: Vital expansion binaries are completely absent from initramfs scope bounds."
    exit 0
fi

cmdline_stream=$(cat /proc/cmdline)
root_id_str=""
for param in $cmdline_stream; do
    case "$param" in
        root=*) root_id_str="${param#root=}" ;;
    esac
done

if [ -z "$root_id_str" ]; then
    echo "[F2FS-Expand] ERROR: Unable to isolate root device parameters from cmdline stream."
    exit 0
fi

echo "[F2FS-Expand] Target storage token trapped from kernel parameters: $root_id_str"
root_block_node=""

if echo "$root_id_str" | grep -q "="; then
    probe_type=$(echo "$root_id_str" | cut -d= -f1)
    probe_value=$(echo "$root_id_str" | cut -d= -f2-)
    
    echo "[F2FS-Expand] Resolving $probe_type mapping via absolute raw block device node interrogation..."
    for test_node in /dev/mmcblk*p* /dev/sd* /dev/nvme*p* /dev/mapper/*; do
        if [ -b "$test_node" ]; then
            resolved_val=$(blkid -o value -s "$probe_type" "$test_node" 2>/dev/null)
            if [ "$resolved_val" = "$probe_value" ]; then
                root_block_node="$test_node"
                break
            fi
        fi
    done
else
    root_block_node="$root_id_str"
fi

if [ -z "$root_block_node" ] || [ ! -b "$root_block_node" ]; then
    echo "[F2FS-Expand] WARNING: Flash-node tracking fell back to standard evaluation."
    root_block_node=$(findfs "$root_id_str" 2>/dev/null || blkid -U "${root_id_str#UUID=}" 2>/dev/null)
    [ -z "$root_block_node" ] && root_block_node="$root_id_str"
fi

echo "[F2FS-Expand] Isolated live root physical target block node: $root_block_node"

if [ ! -b "$root_block_node" ]; then
    echo "[F2FS-Expand] CRITICAL FAULT: Target is not a valid block device node. Aborting resize execution."
    exit 0
fi

if echo "$root_block_node" | grep -q -E 'p[0-9]+$'; then
    parent_disk=$(echo "$root_block_node" | sed -E 's/p[0-9]+$//')
    part_num=$(echo "$root_block_node" | grep -o -E '[0-9]+$')
else
    parent_disk=$(echo "$root_block_node" | sed -E 's/[0-9]+$//')
    part_num=$(echo "$root_block_node" | grep -o -E '[0-9]+$')
fi

echo "[F2FS-Expand] Altering partition table geometry on $parent_disk allocation index $part_num..."
parted -s -f "$parent_disk" resizepart "$part_num" 100%

echo "[F2FS-Expand] Requesting kernel partition cache re-index on $parent_disk..."
if type partprobe >/dev/null 2>&1; then
    partprobe "$parent_disk" >/dev/null 2>&1
fi
if type udevadm >/dev/null 2>&1; then
    udevadm settle --timeout=5 >/dev/null 2>&1
fi
sleep 1

# ---------------------------------------------------------------------
# Defensive Interactive Logging Extraction Block (Anti-Block Buffering)
# ---------------------------------------------------------------------
# By dumping interactive output to a temporary file, we capture block-buffered
# data from the C binary completely. Then, reading line-by-line prevents 
# BusyBox POSIX sh pipeline failure masking bugs (absence of pipefail option).
echo "[F2FS-Expand] Executing offline structural cluster growth scaling via resize.f2fs..."
resize_log="/tmp/resize_f2fs_runtime.log"
set +e
echo "y" | resize.f2fs "$root_block_node" > "$resize_log" 2>&1
resize_exit_code=$?
set -e

if [ -f "$resize_log" ]; then
    while read -r log_line; do
        if [ -d /scripts/local-premount ]; then
            echo "[F2FS-Resize] $log_line" > /dev/kmsg
        else
            echo "[F2FS-Resize] $log_line"
        fi
    done < "$resize_log"
    rm -f "$resize_log"
fi

if [ $resize_exit_code -ne 0 ]; then
    echo "[F2FS-Expand] CRITICAL: resize.f2fs execution failed with exit code $resize_exit_code"
    exit $resize_exit_code
fi
# ---------------------------------------------------------------------

mkdir -p /tmp/mnt_boot
boot_block_node=$(echo "$root_block_node" | sed -E 's/p2$/p1/;s/2$/1/')
if [ -b "$boot_block_node" ]; then
    mount "$boot_block_node" /tmp/mnt_boot 2>/dev/null
    if [ -f /tmp/mnt_boot/cmdline.txt ]; then
        sed -i 's|init=/usr/lib/raspi-config/init_resize.sh||g' /tmp/mnt_boot/cmdline.txt
    fi
    umount /tmp/mnt_boot /dev/null 2>&1 || umount -fl /tmp/mnt_boot /dev/null || true
fi
echo "[F2FS-Expand] Expansion sequence successfully completed. Handing over to root init."
EOF
)

    # --- Framework Route Allocation Pathing ---
    if [[ "${staging_framework}" == "dracut" ]]; then
        echo -e "${COLOR_LBLUE}[PID: ${$}] Creating automated early-boot Dracut expansion module workspace . . .${COLOR_NC}"
        module_dir="${mounted_tmp_part}/usr/lib/dracut/modules.d/99f2fs-expand"
        mkdir -p "${module_dir}"
        
        echo "${hook_script_content}" > "${module_dir}/f2fs-expand.sh"
        chmod +x "${module_dir}/f2fs-expand.sh"
        
        cat << 'EOF' > "${module_dir}/module-setup.sh"
#!/bin/bash
check() { return 0; }
depends() { return 0; }
install() {
    inst_hook pre-mount 99 "${moddir}/f2fs-expand.sh"
    inst_multiple parted partprobe udevadm resize.f2fs fsck.f2fs blkid sed readlink findfs sleep
}
EOF
        chmod +x "${module_dir}/module-setup.sh"

    elif [[ "${staging_framework}" == "initramfs-tools" ]] || [[ "${staging_framework}" == "debian-baremetal" ]]; then
        echo -e "${COLOR_LBLUE}[PID: ${$}] Injecting automated early-boot Debian initramfs-tools expansion hook scripts . . .${COLOR_NC}"
        creation_hook_dir="${mounted_tmp_part}/etc/initramfs-tools/hooks"
        live_hook_dir="${mounted_tmp_part}/etc/initramfs-tools/scripts/local-premount"
        mkdir -p "${creation_hook_dir}"
        mkdir -p "${live_hook_dir}"

        cat << 'EOF' > "${creation_hook_dir}/f2fs-expand"
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in prereqs) prereqs; exit 0;; esac
. /usr/share/initramfs-tools/hook-functions

copy_exec "$(command -v parted)"
copy_exec "$(command -v partprobe)" 2>/dev/null || true
copy_exec "$(command -v udevadm)" 2>/dev/null || true
copy_exec "$(command -v blkid)"
copy_exec "$(command -v sed)"
copy_exec "$(command -v readlink)"
copy_exec "$(command -v findfs)"
copy_exec "$(command -v fsck.f2fs)"
copy_exec "$(command -v sleep)"

ln -sf fsck.f2fs "${DESTDIR}/usr/sbin/resize.f2fs"
ln -sf fsck.f2fs "${DESTDIR}/sbin/resize.f2fs"
EOF
        chmod +x "${creation_hook_dir}/f2fs-expand"
        
        echo "${hook_script_content}" > "${live_hook_dir}/f2fs-expand"
        chmod +x "${live_hook_dir}/f2fs-expand"
        
        if ! grep -q "^f2fs" "${mounted_tmp_part}/etc/initramfs-tools/modules" 2>/dev/null; then
            echo "f2fs" >> "${mounted_tmp_part}/etc/initramfs-tools/modules"
        fi
    fi
}

# =====================================================================
# Function    : ensure_target_f2fs_tools
# Description : Bypasses repository constraints by sourcing and compiling f2fs-tools.
# Arguments   : None
# =====================================================================
ensure_target_f2fs_tools() {
    if chroot "${mounted_tmp_part}" /sbin/mkfs.f2fs -V >/dev/null 2>&1; then
        echo -e "${COLOR_GREEN}Native mkfs.f2fs binary already verified inside container.${COLOR_NC}"
        return 0
    fi

    echo -e "${COLOR_LBLUE}[PID: ${$}] Compiling native f2fs-tools via QEMU architecture redirection . . .${COLOR_NC}"
    local backup_resolv=0
    
    if [[ -f "${mounted_tmp_part}/etc/resolv.conf" ]]; then
        mv "${mounted_tmp_part}/etc/resolv.conf" "${mounted_tmp_part}/etc/resolv.conf.bak"
        backup_resolv=1
    fi
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > "${mounted_tmp_part}/etc/resolv.conf"

    chroot "${mounted_tmp_part}" /bin/bash -c "
        set -e
        if [ -x /usr/bin/dnf ] || [ -x /usr/bin/dnf5 ]; then
            echo 'max_parallel_downloads=10' >> /etc/dnf/dnf.conf
            dnf install -y git gcc autoconf libtool libuuid-devel libblkid-devel pkgconf make parted ${install_lvm2}
        elif [ -x /usr/bin/apt-get ] || [ -x /usr/bin/apt ]; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -o Dpkg::Use-Pty=0
            apt-get install -y \
                -o Dpkg::Use-Pty=0 \
                -o Dpkg::Options::=\"--force-confdef\" \
                -o Dpkg::Options::=\"--force-confold\" \
                git gcc autoconf libtool uuid-dev libblkid-dev pkg-config make parted initramfs-tools ${install_lvm2}
        else
            exit 1
        fi

        git clone https://git.kernel.org/pub/scm/linux/kernel/git/jaegeuk/f2fs-tools.git /tmp/f2fs-tools
        cd /tmp/f2fs-tools
        ./autogen.sh && ./configure --prefix=/usr && make -j2 && make install
        cd /tmp && rm -rf /tmp/f2fs-tools
    "
    
    rm -f "${mounted_tmp_part}/etc/resolv.conf"
    [[ "${backup_resolv}" -eq 1 ]] && mv "${mounted_tmp_part}/etc/resolv.conf.bak" "${mounted_tmp_part}/etc/resolv.conf"
}

# =====================================================================
# Function    : rebuild_initramfs
# Description : Rebuilds the core initramfs package inside the staging layout.
# Arguments   : None
# =====================================================================
rebuild_initramfs() {
    local kver=""
    local latest_initramfs=""
    local latest_initrd=""
    local target_boot_mount=""

    if [[ -d "${mounted_tmp_part}/boot/firmware" ]]; then
        target_boot_mount="${mounted_tmp_part}/boot/firmware"
    else
        target_boot_mount="${mounted_tmp_part}/boot"
    fi

    if [[ "${staging_framework}" == "dracut" ]]; then
        echo -e "${COLOR_LBLUE}[PID: ${$}] Rebuilding Enterprise initramfs layer inside staging chroot environment . . .${COLOR_NC}"

        mkdir -p "${target_boot_mount}"
        mount --bind "${mounted_boot_part}" "${target_boot_mount}" 2>/dev/null

        for kver in $(ls "${mounted_tmp_part}/lib/modules"); do
            echo -e "${COLOR_YELLOW}[PID: ${$}] Cooking explicit Dracut ramdisk for targeted kernel version: ${kver}${COLOR_NC}"
            
            if ! chroot "${mounted_tmp_part}" dracut -f --add "f2fs-expand" --add-drivers f2fs "/boot/initramfs-${kver}.img" "${kver}"; then
                echo -e "${COLOR_RED}[PID: ${$}] ERROR: Dracut compilation failure detected inside staging loops.${COLOR_NC}"
                exit 1
            fi
        done
        echo -e "${COLOR_GREEN}[PID: ${$}] Initramfs generic compilation complete.${COLOR_NC}"

        latest_initramfs="$(ls -1t "${mounted_tmp_part}"/boot/initramfs-*.img 2>/dev/null | head -n 1)"
        if [[ -n "${latest_initramfs}" ]]; then
            cp "${latest_initramfs}" "${mounted_boot_part}/initramfs8"
            echo -e "${COLOR_GREEN}[PID: ${$}] Successfully deployed explicit custom ramdisk straight to initramfs8 target block.${COLOR_NC}"
        fi
        umount "${target_boot_mount}" 2>/dev/null || true

    elif [[ "${staging_framework}" == "initramfs-tools" ]] || [[ "${staging_framework}" == "debian-baremetal" ]]; then
        echo -e "${COLOR_LBLUE}[PID: ${$}] Rebuilding Debian initramfs-tools layer inside staging chroot environment . . .${COLOR_NC}"

        mkdir -p "${target_boot_mount}"
        mount --bind "${mounted_boot_part}" "${target_boot_mount}" 2>/dev/null

        for kver in $(ls "${mounted_tmp_part}/lib/modules"); do
            echo -e "${COLOR_YELLOW}[PID: ${$}] Cooking explicit update-initramfs for targeted kernel version: ${kver}${COLOR_NC}"
            if [[ ! -f "${mounted_tmp_part}/boot/config-${kver}" && "${target_boot_mount}" == "${mounted_tmp_part}/boot" ]]; then
                echo -e "CONFIG_RD_GZIP=y\nCONFIG_RD_ZSTD=y" > "${mounted_tmp_part}/boot/config-${kver}"
            fi

            if ! chroot "${mounted_tmp_part}" update-initramfs -c -k "${kver}" 2>/dev/null; then
                if ! chroot "${mounted_tmp_part}" update-initramfs -u -k "${kver}"; then
                    echo -e "${COLOR_RED}[PID: ${$}] ERROR: update-initramfs compilation failure detected inside staging loops.${COLOR_NC}"
                    exit 1
                fi
            fi
        done
        echo -e "${COLOR_GREEN}[PID: ${$}] Debian initramfs compilation complete.${COLOR_NC}"

        latest_initrd="$(ls -1t "${mounted_tmp_part}"/boot/initrd.img-* 2>/dev/null | head -n 1)"
        if [[ -n "${latest_initrd}" ]]; then
            cp "${latest_initrd}" "${mounted_boot_part}/initrd.img"
            echo -e "${COLOR_GREEN}Successfully deployed generic initrd.img straight to boot partition folder root.${COLOR_NC}"
        fi
        umount "${target_boot_mount}" 2>/dev/null || true
    fi
}

# =====================================================================
# Function    : clean_container_packages
# Description : Thoroughly strips down development headers files inside chroot right before packing.
# Arguments   : None
# =====================================================================
clean_container_packages() {
    echo -e "${COLOR_YELLOW}[PID: ${$}] Cleaning up compilation build assets from internal staging workspace...${COLOR_NC}"
    chroot "${mounted_tmp_part}" /bin/bash -c "
        if [ -x /usr/bin/dnf ] || [ -x /usr/bin/dnf5 ]; then
            dnf remove -y git gcc autoconf libtool libuuid-devel libblkid-devel pkgconf make
            dnf autoremove -y
            dnf clean all
            sed -i '/max_parallel_downloads=10/d' /etc/dnf/dnf.conf
        elif [ -x /usr/bin/apt-get ] || [ -x /usr/bin/apt ]; then
            apt-get purge -y git gcc autoconf libtool uuid-dev libblkid-dev pkg-config make
            apt-get autoremove -y
            apt-get clean
        fi
    " 2>/dev/null || true
}

# =====================================================================
# Function    : rename_extracted_file
# Description : Modifies the name extension to reflect new structural changes.
# Arguments   : $1 - Raw image file string reference
# =====================================================================
rename_extracted_file() {
    local dirname=""
    local filename=""
    local extension=""
    local target=""
    dirname="$(dirname "${1}")"
    filename="$(basename "${1}")"
    extension="${filename#*.}"
    filename="$(echo "${filename}" | awk -F".${extension}" '{print $1}')"

    filename="${filename}-f2fs"
    target="${dirname}/${filename}.${extension}"
    mv "${1}" "${target}"
    echo "${target}"
}

# =====================================================================
# Function    : compress_modified_image
# Description : Wraps target output distribution utilizing dynamic presets.
#               Supports on-the-fly injection via COMPRESSION_PRESET env var.
# Arguments   : $1 - Output target build string file path location
# =====================================================================
compress_modified_image() {
    local target_file="${1}"
    
    # Capture dynamic injection or fallback to the industry standard (Preset 5)
    local preset="${COMPRESSION_PRESET:-5}"
    
    # Defensive validation guard: Ensure that the preset is a strictly safe single digit (0-9)
    if [[ ! "${preset}" =~ ^[0-9]$ ]]; then
        echo -e "${COLOR_YELLOW}[WARN] Invalid COMPRESSION_PRESET format ['${preset}']. Falling back to Preset 5.${COLOR_NC}"
        preset=5
    fi
    
    echo -e "${COLOR_LBLUE}[PID: ${$}] Compressing image payload utilizing PRESET ${preset} (Threads: 2) . . .${COLOR_NC}"
    
    # Execute atomic compression with dynamic parameterization
    xz -zfv"${preset}" -T2 "${target_file}"
}

# =====================================================================
# Function    : delay
# Description : High-granularity decimal micro-jitter delay configured with a 
#               0.2s step interval and a strict ceiling maximum of 4.0 seconds.
#               Enforces LC_NUMERIC=C to guarantee uniform floating-point 
#               parsing by the sleep command across international locales.
# Arguments   : None
# =====================================================================
delay() {
    local interval_multiplier=$(( (RANDOM % 20) + 1 ))
    local total_tenths=$(( interval_multiplier * 2 ))
    local jitter_delay
    
    jitter_delay=$(printf "%d.%d" $((total_tenths / 10)) $((total_tenths % 10)))

    echo -e "${COLOR_YELLOW}[PID: ${$}] Staggering loop device allocation context for ${jitter_delay}s to avoid kernel collisions...${COLOR_NC}"
    
    LC_NUMERIC=C sleep "${jitter_delay}"
}

# =====================================================================
# Function    : detect_os_framework_profile
# Description : Identifies the target image initramfs compilation framework.
# Arguments   : None
# =====================================================================
detect_os_framework_profile() {
    if [[ -x "${mounted_root_part}/usr/bin/dracut" ]] || [[ -x "${mounted_root_part}/usr/sbin/dracut" ]]; then
        staging_framework="dracut"
    elif [[ -x "${mounted_root_part}/usr/sbin/update-initramfs" ]] || [[ -x "${mounted_root_part}/usr/bin/apt-get" ]]; then
        staging_framework="initramfs-tools"
    else
        staging_framework="none"
    fi
    echo -e "${COLOR_GREEN}[PID: ${$}] Isolated container storage runtime framework profile: ${COLOR_WHITE}${staging_framework}${COLOR_NC}"
}

# =====================================================================
# Function    : evaluate_distro_dependencies
# Description : Determines if explicit enterprise dependencies are required.
# Arguments   : None
# =====================================================================
evaluate_distro_dependencies() {
    if echo "${image_base}" | grep -q -E -i 'almalinux|fedora|rocky'; then
        install_lvm2="lvm2"
    fi
}

# =====================================================================
# Function    : initialize_temporary_f2fs_staging
# Description : Builds secondary transactional f2fs staging layouts and clones filesystem content.
# Arguments   : None
# =====================================================================
initialize_temporary_f2fs_staging() {
    local fs_size
    fs_size="$(calculate_fs_size "${mounted_root_part}")"
    create_and_mount_temporary_f2fs_drive "${fs_size}"
    backup_root_content

    echo -e "${COLOR_YELLOW}Live image baseline synchronized. Storage partition is unlocked for modification.${COLOR_NC}"
}

# =====================================================================
# Function    : commit_f2fs_payload
# Description : Executes filesystem formatting, structural fstab modifications, 
#               and data deployment back to the native hardware block layers.
# Arguments   : None
# =====================================================================
commit_f2fs_payload() {
    format_root_as_f2fs "${root_loop_dev_node}"
    patch_system_file "${root_loop_dev_node}"
    restore_root_content "${root_loop_dev_node}"

    echo -e "${COLOR_GREEN}[PID: ${$}] Operational contents successfully written and deployed to target partition layout.${COLOR_NC}"
}

# =====================================================================
# Function    : teardown_success_workspaces
# Description : Standard cleanup routine designed to gracefully release locks 
#               and unmount storage nodes before the final compression phase.
# Arguments   : None
# =====================================================================
teardown_success_workspaces() {
    echo -e "${COLOR_LBLUE}[PID: ${$}] Initializing structured success-path teardown sequence...${COLOR_NC}"
    local target_loop=""
    sync
    
    if [[ -n "${mounted_tmp_part}" && "${mounted_tmp_part}" != "/" ]]; then
        for dir in run sys proc dev/pts dev; do
            umount -Rfl "${mounted_tmp_part}/${dir}" 2>/dev/null || true
        done
        umount -Rfl "${mounted_tmp_part}/boot/firmware" >/dev/null 2>&1 || true
        umount -Rfl "${mounted_tmp_part}/boot" >/dev/null 2>&1 || true
        umount -Rfl "${mounted_tmp_part}" 2>/dev/null || true
    fi
    
    if [[ -n "${mount_parent}" && "${mount_parent}" != "/" ]]; then
        for mnt in "${mount_dir_array[@]}"; do
            umount -Rfl "${mnt}" 2>/dev/null || true
        done
    fi
    
    if command -v vgchange >/dev/null 2>&1; then
        vgchange -an > /dev/null 2>&1
    fi
    
    if [[ -n "${temp_fs_file}" ]]; then
        local intermediate_loop=""
        intermediate_loop=$(losetup -a 2>/dev/null | grep "$(basename "${temp_fs_file}")" | cut -d: -f1)
        if [[ -n "${intermediate_loop}" ]]; then
            kpartx -dv "${intermediate_loop}" >/dev/null 2>&1 || true
            losetup -d "${intermediate_loop}" 2>/dev/null || true
        fi
        rm -f "${temp_fs_file}" >/dev/null 2>&1 || true
    fi
    
    if [[ -n "${extracted_file}" ]]; then
        kpartx -dv "${extracted_file}" >/dev/null 2>&1 || true
        target_loop=$(losetup -a 2>/dev/null | grep "$(basename "${extracted_file}")" | cut -d: -f1)
        if [[ -n "${target_loop}" ]]; then
            losetup -d "${target_loop}" 2>/dev/null || true
        fi
    fi
    
    if [[ -n "${mount_parent}" && "${mount_parent}" != "/" && -d "${mount_parent}" ]]; then
        rm -rf "${mount_parent}" 2>/dev/null || true
    fi
}

# =====================================================================
# Function    : finalize_image_packaging
# Description : Computes output file string manipulation parameters and executes core xz archiving.
# Arguments   : None
# =====================================================================
finalize_image_packaging() {
    patched_file="$(rename_extracted_file "${extracted_file}")"
    compress_modified_image "${patched_file}"
}

# =====================================================================
# Function    : report_performance_metrics
# Description : Calculates exact execution elapsed time benchmarks.
# Arguments   : None
# =====================================================================
report_performance_metrics() {
    end_time="$(date +%s)"
    local total_runtime=$((end_time - start_time))
    local runtime_minutes=$((total_runtime / 60))
    local runtime_seconds=$((total_runtime % 60))

    echo -e "${COLOR_GREEN}[PID: ${$}] Success: Custom filesystem architecture conversion script complete.${COLOR_NC}"
    echo -e "${COLOR_GREEN}Output distribution ready build path location: ${COLOR_WHITE}${patched_file}.xz${COLOR_NC}"
    echo -e "${COLOR_GREEN}Total Execution Time: ${COLOR_WHITE}${runtime_minutes}m ${runtime_seconds}s${COLOR_NC}"
}

# =====================================================================
# Function    : close_logging_streams
# Description : Orderly closes log recording descriptors, tearing down background tee pipes gracefully.
# Arguments   : None
# =====================================================================
close_logging_streams() {
    exec 1>&3 2>&4 3>&- 4>&- 2>/dev/null || true
}

# =====================================================================
# Function    : sanitize_log_file
# Description : Fallback function to guarantee that ANSI escape color codes
#               are completely stripped from the final production log report.
# Arguments   : None
# =====================================================================
sanitize_log_file() {
    local temp_log
    if [[ -f "${log_file:-}" ]]; then
        temp_log="${log_file}.tmp"
        if sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "${log_file}" > "${temp_log}"; then
            mv "${temp_log}" "${log_file}"
        else
            rm -f "${temp_log}"
        fi
    fi
}

# =====================================================================
# Function    : setup_logging_streams
# Description : Locks active log mirrors, duplicating standard file descriptors into channels 3 and 4.
# Arguments   : None
# =====================================================================
setup_logging_streams() {
    echo "=== rpif2fs Parallel Image Conversion Log for ${image_base}: $(date) ===" > "${log_file}"
    exec 3>&1 4>&2
    
    # Streaming architecture utilizing host standard descriptor mapping
    exec > >(tee /dev/fd/3 | sed -u -E -e 's/.*\r//' -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "${log_file}") 2>&1

    echo -e "${COLOR_GREEN}Target image designated: ${COLOR_WHITE}${xz_img}${COLOR_NC}"
    echo -e "${COLOR_GREEN}Asynchronous system logs are systematically mirrored to: ${COLOR_WHITE}${log_file}${COLOR_NC}"
}

# =====================================================================
# Function    : cleanup
# Description : Emergency response handler designed to systematically clean 
#               up virtual filesystems and loops during execution faults.
# Arguments   : None
# =====================================================================
cleanup() {
    # Immediately neutralize all active traps to prevent recursion or lock collision
    trap - EXIT INT TERM

    echo -e "${COLOR_YELLOW}[PID: ${$}] Critical Section Trap Alert: Triggering emergency fallback purger...${COLOR_NC}"
    
    if [[ -n "${mount_parent}" && "${mount_parent}" != "/" ]]; then
        local pid
        for pid_dir in /proc/[0-9]*; do
            pid=$(basename "${pid_dir}")
            
            if [[ "${pid}" -eq "$$" || "${pid}" -eq "${PPID}" || "${pid}" -eq 1 ]]; then
                continue
            fi
            
            if [[ -d "${pid_dir}" ]]; then
                local kill_proc=0
                if readlink "${pid_dir}/root" 2>/dev/null | grep -q "^${mount_parent}"; then kill_proc=1; fi
                if readlink "${pid_dir}/cwd" 2>/dev/null | grep -q "^${mount_parent}"; then kill_proc=1; fi
                if [[ "${kill_proc}" -eq 0 && -d "${pid_dir}/fd" ]]; then
                    for fd in "${pid_dir}/fd"/*; do
                        if readlink "${fd}" 2>/dev/null | grep -q "^${mount_parent}"; then kill_proc=1; break; fi
                    done
                fi
                if [[ "${kill_proc}" -eq 1 ]]; then
                    kill -9 "${pid}" 2>/dev/null || true
                fi
            fi
        done
    fi

    if [[ -n "${mounted_tmp_part}" && "${mounted_tmp_part}" != "/" ]]; then
        for dir in run sys proc dev/pts dev; do
            umount -Rfl "${mounted_tmp_part}/${dir}" 2>/dev/null || true
        done
        umount -Rfl "${mounted_tmp_part}/boot/firmware" >/dev/null 2>&1 || true
        umount -Rfl "${mounted_tmp_part}/boot" >/dev/null 2>&1 || true
        umount -Rfl "${mounted_tmp_part}" 2>/dev/null || true
    fi

    if [[ -n "${mount_parent}" && "${mount_parent}" != "/" ]]; then
        for mnt in "${mount_dir_array[@]}"; do
            umount -Rfl "${mnt}" 2>/dev/null || true
        done
        umount -Rfl "${mount_parent}" >/dev/null 2>&1 || true
        rm -rf "${mount_parent}" >/dev/null 2>&1 || true
    fi

    if [[ -n "${temp_fs_file}" ]]; then
        local intermediate_loop=""
        intermediate_loop=$(losetup -a 2>/dev/null | grep "$(basename "${temp_fs_file}")" | cut -d: -f1)
        if [[ -n "${intermediate_loop}" ]]; then
            kpartx -dv "${intermediate_loop}" >/dev/null 2>&1 || true
            losetup -d "${intermediate_loop}" 2>/dev/null || true
        fi
        rm -f "${temp_fs_file}" >/dev/null 2>&1 || true
    fi

    if [[ -n "${extracted_file}" ]]; then
        if command -v vgchange >/dev/null 2>&1; then
            vgchange -an > /dev/null 2>&1
        fi
        kpartx -dv "${extracted_file}" >/dev/null 2>&1 || true
        
        local target_loop=""
        target_loop=$(losetup -a 2>/dev/null | grep "$(basename "${extracted_file}")" | cut -d: -f1)
        [[ -n "${target_loop}" ]] && losetup -d "${target_loop}" 2>/dev/null || true
    fi

    if [[ -n "$(declare -f close_logging_streams)" ]]; then
        close_logging_streams
    fi

    if [[ -n "$(declare -f sanitize_log_file)" ]]; then
        sanitize_log_file
    fi

    remove_lock
}

# =====================================================================
# Function    : parse_arguments_and_select_file
# Description : Validates terminal argument pathing or triggers GUI selection windows.
# Arguments   : $@ - Parameters passed to the script
# =====================================================================
parse_arguments_and_select_file() {
    if [[ -n "${1}" ]]; then
        if [[ -f "${1}" ]]; then
            xz_img="${1}"
        else
            echo -e "${COLOR_RED}ERROR: The specified command line target image path does not exist: ${1}${COLOR_NC}"
            exit 1
        fi
    fi

    while [[ -z "${xz_img}" ]]
    do
        select_file
        if [[ -z "${xz_img}" ]]; then
            echo -e "${COLOR_YELLOW}Selection canceled. Please provide a path argument or pick a target file.${COLOR_NC}"
            exit 1
        fi
    done
}

# =====================================================================
# Function    : prepare_workspaces_and_mounts
# Description : Manages raw file decompression, serialization delays, and device mapper setup.
# Arguments   : None
# =====================================================================
prepare_workspaces_and_mounts() {
    extract_file "${xz_img}"
    extracted_file="$(get_extracted_file_path "${xz_img}")"

    sync
    delay
    loop_devices=( $(map_and_get_loop_devices "${extracted_file}") )
    scan_and_mount_system_layout
}

# =====================================================================
# Main Execution Orchestrator Pipeline Runtime Context Loop Entrypoint
# =====================================================================
main() {
    start_time="$(date +%s)"

    sanity_check
    install_dependencies
    parse_arguments_and_select_file "$@"
    initialize_instance_paths "${xz_img}"
    acquire_lock

    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    setup_logging_streams
    prepare_workspaces_and_mounts
    detect_os_framework_profile
    evaluate_distro_dependencies
    initialize_temporary_f2fs_staging
    
    mount_chroot_pseudo_filesystems

    inject_initramfs_expansion_hook  
    ensure_target_f2fs_tools         
    rebuild_initramfs                
    clean_container_packages         

    commit_f2fs_payload
    teardown_success_workspaces
    
    finalize_image_packaging
    report_performance_metrics
    close_logging_streams
    sanitize_log_file
    
    trap - EXIT INT TERM
    remove_lock
}

main "$@"
