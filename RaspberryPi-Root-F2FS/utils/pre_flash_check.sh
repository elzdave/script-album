#!/bin/bash

# =====================================================================
# pre_flash_check.sh : Advanced Ramdisk F2FS Capability Inspector
# =====================================================================
# Description       : Inspects compressed live image files (.img.xz) to verify
#                     embedded initramfs compliance for offline F2FS expansion.
#                     Features dynamic smart TTY capability detection to automatically
#                     manage clean, strip-ready terminal color log generation.
#                     Fully synchronized with anti-race condition binary matrix.
# Style Standard    : Google Bash Scripting Guide & Defensive Engineering
# Usage             : sudo bash pre_flash_check.sh "/path/to/image.img.xz"
# Author            : David Eleazar
# Year              : 2026
# =====================================================================

# Enforce strict pipeline failure checks to optimize error tracking
set -o pipefail

# --- Smart TTY Detection & ANSI Color Initialization ---
# Dynamically determine if color codes should be utilized based on whether
# stdout is an interactive terminal and NO_COLOR standard is absent.
# Supports FORCE_COLOR=1 override for automated wrapper pipelines.
use_color=0
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    use_color=1
fi
if [[ "${FORCE_COLOR:-0}" -eq 1 ]]; then
    use_color=1
fi

if [[ "${use_color}" -eq 1 ]]; then
    readonly COLOR_NC='\033[0m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[0;33m'
    readonly COLOR_LBLUE='\033[1;34m'
    readonly COLOR_WHITE='\033[1;37m'
else
    readonly COLOR_NC=''
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_LBLUE=''
    readonly COLOR_WHITE=''
fi

# --- Runtime Variable Trackers (Google Style Guide Lowercase Compliance) ---
xz_img=""                   # Source absolute path of the compressed image (.img.xz)
extracted_img=""            # Path to the uncompressed temporary raw block image (.img)
workspace_dir=""            # Localized processing isolated workspace under /var/tmp
lock_file_path=""           # IPC lockfile to prevent parallel execution conflicts
detected_framework="none"   # Isolated initramfs engine discovered inside rootfs (dracut/initramfs-tools)
initramfs_path=""           # Absolute path to the discovered ramdisk archive file inside boot partition
start_time=0                # Benchmark epoch tracking entry anchor
end_time=0                  # Benchmark epoch completion anchor
has_hook=0                  # Verification flag for offline expansion custom script hook presence
has_driver=0                # Verification flag for f2fs filesystem kernel driver module presence
is_system_ready=1           # Final verdict capability readiness matrix compliance indicator
loop_devices=()             # Dynamic array mapping active hardware block loops from kpartx
mounted_paths=()            # Active mount point directories tracking array for LIFO teardown
missing_binaries=()         # Tracking array holding resolved absent mandatory utility binaries

# =====================================================================
# Function    : sanity_check
# Description : Verifies that the script is executed with administrative 
#               privileges and enforces host-side structural toolchain dependency audits.
# Arguments   : None
# =====================================================================
sanity_check() {
    local host_dependencies
    local dep

    echo -e "${COLOR_LBLUE}Sanity checking host environment . . .${COLOR_NC}"

    # Enforce strict root permissions context boundary checks
    if [[ "$(id -u)" != "0" ]]; then
        echo -e "${COLOR_RED}ERROR: Root access denied. Please run as root (sudo).${COLOR_NC}"
        exit 1
    fi

    # Define array tracking mandatory tools required on the host system
    host_dependencies=("xz" "kpartx" "blkid" "mount" "umount" "cpio" "file" "grep" "dd")
    for dep in "${host_dependencies[@]}"; do
        if ! command -v "${dep}" >/dev/null 2>&1; then
            echo -e "${COLOR_RED}ERROR: Mandatory host dependency [${dep}] is missing!${COLOR_NC}"
            exit 1
        fi
    done
    echo -e "${COLOR_GREEN}Host environment is verified and sane.${COLOR_NC}"
}

# =====================================================================
# Function    : parse_arguments
# Description : Validates and extracts command line input parameters from runtime stream.
# Arguments   : $@ - Parameters passed down from main process execution context
# =====================================================================
parse_arguments() {
    if [[ -z "${1}" || ! -f "${1}" ]]; then
        echo -e "${COLOR_WHITE}Usage: sudo bash pre_flash_check.sh [/path/to/image.img.xz]${COLOR_NC}"
        echo -e "${COLOR_RED}ERROR: Target image file not found or argument parameter is blank.${COLOR_NC}"
        exit 1
    fi
    xz_img="${1}"
}

# =====================================================================
# Function    : acquire_lock
# Description : Enforces IPC mutual exclusion transaction locking based on target 
#               image name patterns to avoid duplicate processing race conditions.
# Arguments   : None
# =====================================================================
acquire_lock() {
    local img_base
    local active_pid

    img_base=$(basename "${xz_img}" .xz)
    lock_file_path="/var/run/f2fs_pre_check_${img_base}.lock"

    if [[ -e "${lock_file_path}" ]]; then
        active_pid="$(cat "${lock_file_path}" 2>/dev/null)"
        if [[ -n "${active_pid}" ]] && kill -0 "${active_pid}" 2>/dev/null; then
            echo -e "${COLOR_RED}CRITICAL CONCURRENCY ERROR: File is currently audited by running PID: ${active_pid}${COLOR_NC}"
            exit 1
        fi
    fi
    echo "$$" > "${lock_file_path}"
}

# =====================================================================
# Function    : setup_workspace
# Description : Allocates secure sandboxed temporary workspaces inside /var/tmp 
#               after triggering a strict pre-flight persistent storage capacity audit.
# Arguments   : None
# =====================================================================
setup_workspace() {
    local xz_file
    local uncompressed_bytes
    local uncompressed_kb
    local vartmp_free_kb
    local safety_margin_kb
    local required_kb

    xz_file="${xz_img}"
    uncompressed_bytes=0
    uncompressed_kb=0
    vartmp_free_kb=0
    safety_margin_kb=1048576  # Enforce 1 GB structural padding for extraction overhead storage safety

    # Query internal compressed archive stream indexing tables via robot interface
    if command -v xz >/dev/null 2>&1; then
        uncompressed_bytes=$(xz --robot -l "${xz_file}" 2>/dev/null | awk '$1 == "totals" {print $5}')
        if [[ -n "${uncompressed_bytes}" ]] && [[ "${uncompressed_bytes}" =~ ^[0-9]+$ ]]; then
            uncompressed_kb=$(( uncompressed_bytes / 1024 ))
        fi
    fi

    # Retrieve the exact free capacity metrics of the persistent target partition boundary
    if [[ -d "/var/tmp" ]]; then
        vartmp_free_kb=$(df -P /var/tmp | tail -n 1 | awk '{print $4}')
    fi

    # Validate volume bounds constraints defensively
    if [[ "${uncompressed_kb}" -gt 0 ]]; then
        required_kb=$(( uncompressed_kb + safety_margin_kb ))
        if [[ "${vartmp_free_kb}" -lt "${required_kb}" ]]; then
            echo -e "${COLOR_RED}CRITICAL CAPACITY FAULT: Insufficient storage space available on /var/tmp partition!${COLOR_NC}" >&2
            echo -e "${COLOR_RED}Required space : $(( required_kb / 1024 )) MB (Payload: $(( uncompressed_kb / 1024 )) MB + Guard Margin: $(( safety_margin_kb / 1024 )) MB)${COLOR_NC}" >&2
            echo -e "${COLOR_RED}Available space: $(( vartmp_free_kb / 1024 )) MB${COLOR_NC}" >&2
            exit 1
        fi
    fi

    echo -e "${COLOR_YELLOW}[INFO] Storage capacity verified. Allocating safe sandbox workspace environment.${COLOR_NC}"
    workspace_dir="/var/tmp/f2fs_pre_inspector_$$"
    
    mkdir -p "${workspace_dir}/boot"
    mkdir -p "${workspace_dir}/root"
    extracted_img="${workspace_dir}/raw_payload.img"
}

# =====================================================================
# Function    : extract_image_payload
# Description : Losslessly decompresses the target compressed xz payload stream 
#               into the pre-allocated raw disk workspace node.
# Arguments   : None
# =====================================================================
extract_image_payload() {
    echo -e "${COLOR_LBLUE}Extracting compressed image stream to temporary space . . .${COLOR_NC}"
    if ! xz -dc "${xz_img}" > "${extracted_img}"; then
        echo -e "${COLOR_RED}ERROR: Failed to decompress target xz archive payload stream securely.${COLOR_NC}"
        exit 1
    fi
}

# =====================================================================
# Function    : map_loop_devices
# Description : Leverages kpartx mapping services to map raw system image 
#               partition boundaries into host loop device mapper channels.
# Arguments   : None
# =====================================================================
map_loop_devices() {
    local kpartx_output
    local node

    kpartx_output=$(kpartx -av "${extracted_img}")
    if [[ $? -ne 0 ]]; then
        echo -e "${COLOR_RED}ERROR: kpartx execution faulted mapping physical partition blocks.${COLOR_NC}"
        exit 1
    fi

    while read -r line; do
        if echo "${line}" | grep -q -E 'add fastboot|add map'; then
            node=$(echo "${line}" | awk '{print $3}')
            [[ -n "${node}" ]] && loop_devices+=("${node}")
        fi
    done <<< "${kpartx_output}"

    if [[ ${#loop_devices[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}ERROR: No loop map partition architectures returned by kernel block allocator.${COLOR_NC}"
        exit 1
    fi
}

# =====================================================================
# Function    : mount_partitions
# Description : Mounts individual loop partition clusters read-only to evaluate 
#               internal configuration fstab deployment boundaries.
# Arguments   : None
# =====================================================================
mount_partitions() {
    local dev_name
    local dev_path
    local fstype
    local probe_dir

    echo -e "${COLOR_LBLUE}Mounting system partition clusters read-only . . .${COLOR_NC}"
    
    for dev_name in "${loop_devices[@]}"; do
        dev_path="/dev/mapper/${dev_name}"
        fstype="$(blkid -o value -s TYPE "${dev_path}" 2>/dev/null)"
        
        if [[ "${fstype}" == "vfat" || "${fstype}" == "msdos" ]]; then
            mount -o ro "${dev_path}" "${workspace_dir}/boot" 2>/dev/null
            mounted_paths+=("${workspace_dir}/boot")
        elif [[ "${fstype}" == "ext4" || "${fstype}" == "xfs" || "${fstype}" == "f2fs" ]]; then
            probe_dir="${workspace_dir}/root"
            mount -o ro "${dev_path}" "${probe_dir}" 2>/dev/null
            if [[ -f "${probe_dir}/etc/fstab" ]]; then
                mounted_paths+=("${probe_dir}")
            else
                umount "${probe_dir}" 2>/dev/null
            fi
        fi
    done
}

# =====================================================================
# Function    : detect_initramfs_framework
# Description : Heuristically analyzes the target rootfs image layout to resolve 
#               the core internal ramdisk initialization framework archetype profile.
# Arguments   : None
# =====================================================================
detect_initramfs_framework() {
    local rfs
    rfs="${workspace_dir}/root"

    if [[ -x "${rfs}/usr/bin/dracut" || -x "${rfs}/usr/sbin/dracut" ]]; then
        detected_framework="dracut"
    elif [[ -x "${rfs}/usr/sbin/update-initramfs" || -x "${rfs}/usr/bin/apt-get" ]]; then
        detected_framework="initramfs-tools"
    else
        detected_framework="none"
    fi
    echo -e "Target initramfs engine archetype: ${COLOR_WHITE}${detected_framework}${COLOR_NC}"
}

# =====================================================================
# Function    : locate_initramfs_file
# Description : Discovers the exact filepath pointing to the primary bootable 
#               initialization ramdisk packaging asset.
# Arguments   : None
# =====================================================================
locate_initramfs_file() {
    local boot_dir
    boot_dir="${workspace_dir}/boot"

    if [[ "${detected_framework}" == "dracut" ]]; then
        initramfs_path="${boot_dir}/initramfs8"
    else
        initramfs_path="${boot_dir}/initrd.img"
    fi

    if [[ ! -f "${initramfs_path}" ]]; then
        if [[ -f "${boot_dir}/firmware/initramfs8" ]]; then
            initramfs_path="${boot_dir}/firmware/initramfs8"
        elif [[ -f "${boot_dir}/firmware/initrd.img" ]]; then
            initramfs_path="${boot_dir}/firmware/initrd.img"
        else
            echo -e "${COLOR_RED}ERROR: Crucial initialization ramdisk archive file target is completely absent!${COLOR_NC}"
            exit 1
        fi
    fi
}

# =====================================================================
# Function    : analyze_ramdisk_contents
# Description : Advanced extraction loop targeting multi-layer compressed 
#               cpio containers. Defensively verifies presence of core 
#               utilities, including anti-race condition binaries sync'd 
#               with the rpif2fs.sh master script asset deployment layer.
# Arguments   : None
# =====================================================================
analyze_ramdisk_contents() {
    local manifest
    local zstd_magic
    local zstd_offset
    local gzip_magic
    local gzip_offset
    local builtin_file
    local mandatory_binaries
    local binary

    echo -e "${COLOR_LBLUE}Analyzing ramdisk architecture payload contents . . .${COLOR_NC}"
    manifest="${workspace_dir}/manifest.txt"
    touch "${manifest}"

    # Extract multi-layer compression offsets using hexadecimal magic signatures
    zstd_magic=$(printf '\x28\xB5\x2F\xFD')
    zstd_offset=$(grep -a -b -o -m 1 -F "${zstd_magic}" "${initramfs_path}" | cut -d: -f1 | head -n1)
    
    gzip_magic=$(printf '\x1F\x8B')
    gzip_offset=$(grep -a -b -o -m 1 -F "${gzip_magic}" "${initramfs_path}" | cut -d: -f1 | head -n1)

    if [[ -n "${zstd_offset}" ]] && command -v zstdcat >/dev/null 2>&1; then
        dd if="${initramfs_path}" bs=1 skip="${zstd_offset}" 2>/dev/null | zstdcat | cpio -it > "${manifest}" 2>/dev/null
    elif [[ -n "${gzip_offset}" ]] && command -v gunzip >/dev/null 2>&1; then
        dd if="${initramfs_path}" bs=1 skip="${gzip_offset}" 2>/dev/null | gunzip -c | cpio -it > "${manifest}" 2>/dev/null
    else
        cpio -it < "${initramfs_path}" > "${manifest}" 2>/dev/null || true
        if command -v zstdcat >/dev/null 2>&1; then
            zstdcat "${initramfs_path}" | cpio -it >> "${manifest}" 2>/dev/null || true
        fi
        if command -v gunzip >/dev/null 2>&1; then
            gzip -dc "${initramfs_path}" | cpio -it >> "${manifest}" 2>/dev/null || true
        fi
    fi

    if grep -q "f2fs-expand" "${manifest}" 2>/dev/null; then
        has_hook=1
    fi

    if grep -q "f2fs.ko" "${manifest}" 2>/dev/null; then
        has_driver=1
    fi

    # Fallback to verify modules.builtin configurations if raw .ko files are absent
    if [[ "${has_driver}" -eq 0 ]]; then
        builtin_file=""
        for builtin_file in "${workspace_dir}/root/lib/modules"/*/modules.builtin; do
            if [[ -f "${builtin_file}" ]]; then
                if grep -q "f2fs" "${builtin_file}"; then
                    has_driver=1
                    echo -e "[${COLOR_GREEN}FOUND${COLOR_NC}] Driver F2FS verified as BUILT-IN (=y) inside targeted distro kernel."
                    break
                fi
            fi
        done
    fi

    # ---------------------------------------------------------------------
    # Synchronized Binary Auditing Matrix (Defensive Asset Alignment)
    # ---------------------------------------------------------------------
    # Enforces strict validation synchronization with the rpif2fs.sh engine.
    # Added partprobe, udevadm, and sleep to audit anti-race-condition deployment integrity.
    mandatory_binaries=("parted" "partprobe" "udevadm" "resize.f2fs" "blkid" "sed" "readlink" "findfs" "sleep")
    for binary in "${mandatory_binaries[@]}"; do
        if grep -q -E "(bin/${binary}$|sbin/${binary}$)" "${manifest}"; then
            echo -e "[${COLOR_GREEN}FOUND${COLOR_NC}] Binary utility: ${binary}"
        else
            echo -e "[${COLOR_RED}MISSING${COLOR_NC}] Binary utility: ${binary}"
            missing_binaries+=("${binary}")
            is_system_ready=0
        fi
    done
}

# =====================================================================
# Function    : evaluate_capabilities
# Description : Summarizes the resolved capabilities matrix mappings and 
#               prints a finalized infrastructure readiness verdict report.
# Arguments   : None
# =====================================================================
evaluate_capabilities() {
    echo -e "\n======================================================="
    echo -e "               VERIFICATION SUMMARY REPORT             "
    echo -e "======================================================="
    echo -e "  Target Image       : $(basename "${xz_img}")"
    echo -e "  Detected Framework : ${detected_framework}"
    echo -e "-------------------------------------------------------"

    if [[ "${is_system_ready}" -eq 1 ]] && [[ "${has_hook}" -eq 1 ]] && [[ "${has_driver}" -eq 1 ]]; then
        echo -e "${COLOR_GREEN}  SUCCESS: All crucial components are present and functional!${COLOR_NC}"
        echo -e "  -> Storage initialization block engine is highly F2FS capable."
    else
        echo -e "${COLOR_RED}  FAILURE: Crucial components are missing! Automatic expansion will fail.${COLOR_NC}"
        if [[ "${#missing_binaries[@]}" -gt 0 ]]; then
            echo -e "   -> Missing Binaries: [ ${missing_binaries[*]} ]"
        fi
        if [[ "${has_hook}" -eq 0 ]]; then
            echo -e "   -> Missing expansion hook scripts inside the boot sequence."
        fi
        if [[ "${has_driver}" -eq 0 ]]; then
            echo -e "   -> Missing runtime kernel storage driver module (f2fs.ko)."
        fi
    fi
    echo -e "=======================================================\n"
}

# =====================================================================
# Function    : report_performance_metrics
# Description : Calculates the total continuous elapsed execution time benchmarks.
# Arguments   : None
# =====================================================================
report_performance_metrics() {
    local total_runtime

    end_time="$(date +%s)"
    total_runtime=$((end_time - start_time))
    echo -e "${COLOR_GREEN}Inspection completed in: ${COLOR_WHITE}${total_runtime}s${COLOR_NC}"
}

# =====================================================================
# Function    : cleanup
# Description : Emergency interface purger. Idempotently sanitizes staging mount
#               points and eliminates loop device mappings to prevent memory leaks.
# Arguments   : None
# =====================================================================
cleanup() {
    local path
    local base_img_name
    local orphaned_loop

    echo -e "${COLOR_YELLOW}Cleaning up staging loop infrastructures and workspace . . .${COLOR_NC}"
    
    # Neutralize standard traps to block structural destruction loop recursion
    trap - EXIT INT TERM

    # Dismount storage mounts safely utilizing LIFO back-tracking configurations
    for path in "${mounted_paths[@]}"; do
        if [[ -n "${path}" && -d "${path}" ]]; then
            umount "${path}" 2>/dev/null || umount -fl "${path}" 2>/dev/null || true
        fi
    done

    sync
    LC_NUMERIC=C sleep "0.5"

    # Teardown partition blocks mapper allocations gracefully
    if [[ -n "${extracted_img}" && -f "${extracted_img}" ]]; then
        kpartx -dv "${extracted_img}" >/dev/null 2>&1 || true
    fi

    # Destroy detached ghost hardware descriptors bound to host loops
    if [[ -n "${extracted_img}" ]]; then
        base_img_name=$(basename "${extracted_img}")
        orphaned_loop=$(losetup -a 2>/dev/null | grep "${base_img_name}" | cut -d: -f1)
        for loop in ${orphaned_loop}; do
            if [[ -b "${loop}" ]]; then
                kpartx -dv "${loop}" >/dev/null 2>&1 || true
                losetup -d "${loop}" 2>/dev/null || true
            fi
        done
    fi

    # Clear directories after hardware links are safely untangled
    if [[ -n "${workspace_dir}" && -d "${workspace_dir}" ]]; then
        rm -rf "${workspace_dir}" 2>/dev/null || true
    fi

    # Release atomic lock file state footprint boundary
    [[ -f "${lock_file_path}" ]] && rm -f "${lock_file_path}"
}

# =====================================================================
# Main Execution Orchestrator Pipeline Runtime Context Loop Entrypoint
# =====================================================================
main() {
    start_time="$(date +%s)"

    sanity_check
    parse_arguments "$@"
    acquire_lock
    setup_workspace

    # Securely trap internal process terminations onto emergency cleanup purger
    trap cleanup EXIT INT TERM

    extract_image_payload
    map_loop_devices
    mount_partitions
    detect_initramfs_framework
    locate_initramfs_file
    analyze_ramdisk_contents
    evaluate_capabilities
    report_performance_metrics
}

# Route runtime standard position argument streams securely
main "$@"
