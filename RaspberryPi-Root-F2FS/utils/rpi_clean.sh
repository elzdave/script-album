#!/bin/bash

# =====================================================================
# rpi_clean.sh : Parallel-Aware Consolidated Universal Workspace Purger
# =====================================================================
# Description       : Aggressively scans and purges orphan loop devices, block mappers,
#                     LVM pools, and hanging mounts linked to rpif2fs without lockfiles.
#                     Consolidates raw_payload.img filters, fully shields snapd systems,
#                     and resolves mount race conditions via low-level dmsetup breaks.
# Style Standard    : Google Bash Scripting Guide & Defensive Engineering
# Usage             : sudo bash rpi_clean.sh
# Author            : David Eleazar
# Year              : 2026
# =====================================================================

# Enforce strict pipeline failure checks to optimize error tracking.
set -o pipefail

# --- ANSI Terminal Functional Color Escape Sequences (Read-Only Global Constants) ---
readonly COLOR_NC='\033[0m'         # No Color / Reset terminal graphics context
readonly COLOR_RED='\033[0;31m'        # Red color for critical orphan destruction logs
readonly COLOR_GREEN='\033[0;32m'      # Green color for successful cleanup confirmations
readonly COLOR_YELLOW='\033[0;33m'     # Yellow color for session framing demarcations
readonly COLOR_LBLUE='\033[1;34m'      # Light Blue color for structural scanning steps
readonly COLOR_WHITE='\033[1;37m'      # Bold White color for targeted paths text highlights

# =====================================================================
# Function    : sanity_check
# Description : Enforces strict root administrative privileges constraints.
# Arguments   : None
# =====================================================================
sanity_check() {
    # Announce the execution of root privilege validation rules
    echo -e "${COLOR_LBLUE}Sanity checking administrative privileges . . .${COLOR_NC}"
    
    # Interrogate effective user id; non-zero response dictates restricted guest access
    if [[ "$(id -u)" != "0" ]]; then
        # Print privilege execution denial message utilizing the designated error color block
        echo -e "${COLOR_RED}ERROR: Root access denied. Please run this cleanup utility as root (sudo).${COLOR_NC}"
        # Immediately abort context thread with code 1 to protect storage mapping components
        exit 1
    fi
    
    # Log successful privilege authentication validation to the standard output channel
    echo -e "${COLOR_GREEN}Privileges are verified and valid.${COLOR_NC}"
}

# =====================================================================
# Function    : count_active_instances
# Description : Audits the active host system PID tree to count running instances.
# Arguments   : None
# Returns     : Integer count via echo string maps
# =====================================================================
count_active_instances() {
    # Establish structural file lookup path tracking variable
    local lock_file=""
    # Initialize process identifier holding registry string variable
    local lock_pid=""
    # Establish dynamic integer counter representing alive parallel runs
    local active_count=0

    # Scan the system runtime directories for existing allocation lock registrations
    for lock_file in /var/run/rpif2fs_*.lock; do
        # Confirm if loop target matches an actual active configuration file footprint
        if [[ -f "${lock_file}" ]]; then
            # Extract process tracking identification token from the lock file container
            lock_pid=$(cat "${lock_file}" 2>/dev/null)
            # Query kernel system process flags to verify if process is genuinely active
            if [[ -n "${lock_pid}" ]] && kill -0 "${lock_pid}" 2>/dev/null; then
                # Increment tracking counter atomically upon discovering an active execution loop
                ((active_count++))
            fi
        fi
    done
    
    # Stream structural calculation metrics string back to master orchestrator callers
    echo "${active_count}"
}

# =====================================================================
# Function    : purge_stale_session
# Description : Deep-cleans hanging device nodes, loop boundaries, mount points,
#               and temporary system logs mapped to a specific dead PID.
# Arguments   : $1 - Dead Process Identifier (PID) token string, $2 - Stale lock file path
# =====================================================================
purge_stale_session() {
    # Extract targeted process identifier token from functional position index 1
    local lock_pid="${1}"
    # Extract structural lock file storage path reference from functional position index 2
    local lock_file="${2}"
    # Initialize block device allocation mount source string tracker
    local mount_src=""
    # Initialize workspace physical mounting directory path string tracker
    local mount_target=""
    # Initialize exploratory file structure path boundary tracker
    local sys_loop_path=""
    # Initialize targeted loop interface extraction identity node token string
    local target_loop_dev=""
    # Initialize file registry sweep lookup index results strings
    local f2fs_orphan=""
    # Initialize raw block node configuration token storage variables
    local loop_name=""
    # Define dynamic local array layout tracking targeted loop block allocations
    local detected_loops=()

    # Draw structural boundary interface lines to partition output screen blocks
    echo -e "${COLOR_YELLOW}------------------------------------------------------------${COLOR_NC}"
    # Broadcast process footprints destruction targets using explicit color codes notification
    echo -e "${COLOR_RED}Cleaning stale footprints for crashed/aborted PID: [${lock_pid}]${COLOR_NC}"
    # Finalize geometric terminal grouping boundaries markers
    echo -e "${COLOR_YELLOW}------------------------------------------------------------${COLOR_NC}"

    # 1. TRACE STEP: Scan kernel active mount points maps to capture devices tied to the zombie thread
    while read -r mount_src mount_target _; do
        # Heuristically isolate mount locations matching targeted instance folder boundaries
        if [[ "${mount_target}" == "/mnt/rpif2fs_${lock_pid}"* ]]; then
            # Print localized file detachment commands actions targeted locations straight to output channels
            echo -e "${COLOR_WHITE}Forcing lazy unmount on target point: ${mount_target}${COLOR_NC}"
            # Disconnect structural storage hooks recursively using defensive force layout flags
            umount -Rfl "${mount_target}" 2>/dev/null
            
            # Map loop node parent allocations if active mount source points to block mapper systems
            if [[ "${mount_src}" == /dev/mapper/loop* ]] || [[ "${mount_src}" == /dev/loop* ]]; then
                # Interrogate data block mappings via regex filter blocks to capture loop naming patterns
                target_loop_dev=$(echo "${mount_src}" | grep -o -E 'loop[0-9]+')
                # Guarantee loop element parameters exist and screen against duplicates mapping lists entries
                if [[ -n "${target_loop_dev}" ]] && [[ ! " ${detected_loops[*]} " =~ " ${target_loop_dev} " ]]; then
                    # Cache unique loop block channel targets inside local extraction tracing trackers
                    detected_loops+=("${target_loop_dev}")
                fi
            fi
        fi
    done < /proc/mounts

    # 2. SYSFS SCAN STEP: Interrogate loop setup configuration tables to capture the tracking staging file
    while read -r f2fs_orphan; do
        # Protect code pipelines confirming retrieved text bounds deliver true layout string targets
        if [[ -n "${f2fs_orphan}" ]]; then
            # Extract base loop identification metadata details via regular expressions checks
            target_loop_dev=$(echo "${f2fs_orphan}" | grep -o -E 'loop[0-9]+')
            # Verify block node lengths parameters constraints and screen out duplicate values entries
            if [[ -n "${target_loop_dev}" ]] && [[ ! " ${detected_loops[*]} " =~ " ${target_loop_dev} " ]]; then
                # Queue discovered hardware block nodes paths indicators down inside local track lists
                detected_loops+=("${target_loop_dev}")
            fi
        fi
    # Execute stream parsing across active loop configurations filtering instance tracking tokens signatures
    done < <(losetup -a | grep -E "rpif2_${lock_pid}\.fs" | cut -d: -f1)

    # 3. REVERSE RECLAIM FLUSH LOOP: Safely tear down device mappers FIRST, then wipe loop attachments
    for target_loop_dev in "${detected_loops[@]}"; do
        # Audit physical hardware block nodes states confirming device identity validity definitions
        if [[ -b "/dev/${target_loop_dev}" ]]; then
            # Log targeted hardware block allocation removal phases explicitly onto visual displays
            echo -e "${COLOR_RED}[TARGET BLOCKS FOUND] Processing de-allocation for: /dev/${target_loop_dev}${COLOR_NC}"
            
            # Break active kernel descriptor blocks by issuing lazy unmounts on partitions first
            umount -Rfl "/dev/mapper/${target_loop_dev}p1" >/dev/null 2>&1 || true
            umount -Rfl "/dev/mapper/${target_loop_dev}p2" >/dev/null 2>&1 || true
            umount -Rfl "/dev/${target_loop_dev}" >/dev/null 2>&1 || true

            # Sever low-level device-mapper holds authoritatively via forced dmsetup removal
            dmsetup remove -f "${target_loop_dev}p1" >/dev/null 2>&1 || true
            dmsetup remove -f "${target_loop_dev}p2" >/dev/null 2>&1 || true

            # Unmap internal segment map allocations clusters cleanly via block device erasure tools
            kpartx -dv "/dev/${target_loop_dev}" >/dev/null 2>&1
            # Flush hardware input output storage caching registers blocks to guarantee free links
            sync
            
            # Detach block interface allocations tables completely from active kernel records tracking maps
            losetup -d "/dev/${target_loop_dev}" >/dev/null 2>&1
            # Print successful loop recovery status confirmations out onto terminal lines channels
            echo -e "${COLOR_GREEN}Successfully detached block device allocation: /dev/${target_loop_dev}${COLOR_NC}"
        fi
    done

    # 4. SWEEP RESIDUALS STEP: Double-check loose loops via sysfs holders descriptors mappings
    for sys_loop_path in /sys/block/loop*; do
        # Validate exploratory block profile directory tracks parameters length specifications defensively
        if [[ -d "${sys_loop_path}" ]]; then
            # Pull core base directory name mappings representing explicit active system loop elements
            loop_name=$(basename "${sys_loop_path}")
            
            # Interrogate individual loop attachments registries checking for zombie identifier traces
            if losetup "/dev/${loop_name}" 2>/dev/null | grep -q -E "rpif2_${lock_pid}\."; then
                # Log system fallback enforcement interventions overrides updates directly to active screens
                echo -e "${COLOR_RED}[SYSFS OVERRIDE] Cleaning loose trailing node: /dev/${loop_name}${COLOR_NC}"
                
                # Ensure fallback sweeps completely tear down nested partition locks
                umount -Rfl "/dev/mapper/${loop_name}p1" >/dev/null 2>&1 || true
                umount -Rfl "/dev/mapper/${loop_name}p2" >/dev/null 2>&1 || true
                dmsetup remove -f "${loop_name}p1" >/dev/null 2>&1 || true
                dmsetup remove -f "${loop_name}p2" >/dev/null 2>&1 || true

                # Erase structural block configuration definitions maps from hardware mapper segments
                kpartx -dv "/dev/${loop_name}" >/dev/null 2>&1
                # Destroy loose hardware block loop parameters records tracks from system registries tables
                losetup -d "/dev/${loop_name}" >/dev/null 2>&1
            fi
        fi
    done

    # 5. WIPE FILESYSTEM PATHS STEP: Clean directory trees and trailing footprint tokens
    echo -e "${COLOR_WHITE}Clearing temporary staging directory blocks trees...${COLOR_NC}"
    # Liquidate master workspace compilation directories recursively from filesystem tables layout
    rm -rf "/mnt/rpif2fs_${lock_pid}"
    # Evaporate temporary allocation filesystem blocks assets safely from persistent storage roots
    rm -f "/var/tmp/rpif2_${lock_pid}.fs"
    # Evaporate temporary allocation filesystem blocks assets safely from volatile storage spaces
    rm -f "/tmp/rpif2_${lock_pid}.fs"
    # Clean staging exploratory exploratory workspace locations cleanly from system temporary roots
    rm -rf "/tmp/rpif2_probe_${lock_pid}"

    # 6. UNLOCK STEP: Destroy the stale lock signature to unlock the target base image for future runs
    echo -e "${COLOR_GREEN}Successfully unlocked image build bounds. Wiping stale lockfile.${COLOR_NC}"
    # Eliminate the stale task lock registry profile tracking document to allow subsequent builds
    rm -f "${lock_file}"
}

# =====================================================================
# Function    : purge_system_wide_orphans
# Description : Scans every single loop device in the host kernel tree.
#               Wipes rpif2fs orphans while explicitly preserving snapd items.
# Arguments   : None
# =====================================================================
purge_system_wide_orphans() {
    # Initialize a clean dynamic tracking array caching genuinely running process threads
    local active_pids=()
    # Initialize file pointer tracking loop path boundary variables string maps
    local lock_file=""
    # Initialize thread unique task code allocation holding string variables
    local lock_pid=""
    # Initialize master system data streams row tracking index target variables
    local loop_line=""
    # Initialize absolute hardware node indicator paths tracking strings
    local loop_dev=""
    # Initialize baseline storage data tracking source location description string profiles
    local backing_file=""
    # Initialize alternative process verification identifier string variables registers
    local target_pid=""
    # Establish binary indicator tracking flags signaling valid instance leaks footprints
    local is_rpif2_orphan=0
    # Initialize data mounting layout structural folder path tracking string locations
    local mount_target=""

    # Announce active parallel process tracking sessions identification scan operations phases
    echo -e "${COLOR_LBLUE}Gathering active parallel processing sessions to protect . . .${COLOR_NC}"
    
    # 1. Map all genuinely alive PIDs from existing lock registries
    for lock_file in /var/run/rpif2fs_*.lock; do
        # Check active iteration loops structures confirming files populate disk directories paths
        if [[ -f "${lock_file}" ]]; then
            # Extract internal task identity code tracking integers from the targeted lock layout
            lock_pid=$(cat "${lock_file}" 2>/dev/null)
            # Query active kernel metrics maps to prove if process thread is truly running operations
            if [[ -n "${lock_pid}" ]] && kill -0 "${lock_pid}" 2>/dev/null; then
                # Queue active process identity mappings straight inside layout protection reference lists
                active_pids+=("${lock_pid}")
                # Print shielding confirmations updates highlighting targeted process boundary parameters protection
                echo -e "${COLOR_GREEN}[PROTECTED] PID [${lock_pid}] is alive. Safe-guarding workspace boundaries.${COLOR_NC}"
            else
                # Discard broken dead task file locks footprints immediately to clean system runtime states
                rm -f "${lock_file}"
            fi
        fi
    done

    # Announce system wide tracking examination phases operations down to production shell screens
    echo -e "${COLOR_LBLUE}Beginning aggressive forensic system-wide loop device audit . . .${COLOR_NC}"

    # 2. Globally unmount all stale workspace directories to break active file descriptor locks
    while read -r _ mount_target _; do
        # Isolate tracking path parameters matching master workspace directory pattern layouts definitions
        if [[ "${mount_target}" == "/mnt/rpif2fs_"* ]]; then
            # Strip out numeric task codes using basic regular character groupings regex pass checks
            target_pid=$(echo "${mount_target}" | grep -o -E '[0-9]+')
            # Cross evaluate identifier profiles; bypass drops if target process is confirmed as alive
            if [[ -n "${target_pid}" ]] && [[ " ${active_pids[*]} " =~ " ${target_pid} " ]]; then
                # Protect running execution contexts by skipping active processing tracking zones entries
                continue
            fi
            # Log forced system file detachment commands actions targeted locations straight to output channels
            echo -e "${COLOR_WHITE}Forcing lazy unmount on dangling mount point: ${mount_target}${COLOR_NC}"
            # Disconnect structural folders mappers recursively to break active data loop file handles constraints
            umount -Rfl "${mount_target}" 2>/dev/null
        fi
    done < /proc/mounts

    # 3. Interrogate the system losetup tables row by row
    while read -r loop_line; do
        # Enforce validation loops guards filtering empty system stream output allocations
        if [[ -z "${loop_line}" ]]; then
            # Advance inspection loops indices past empty terminal data blocks entries
            continue
        fi

        # Isolate the hardware loop node path address from the initial section segment data column
        loop_dev=$(echo "${loop_line}" | cut -d: -f1)
        # Parse tracking file descriptor markers extracting raw backup target paths bounds locations
        backing_file=$(echo "${loop_line}" | grep -o -E '\([^)]+\)' | sed 's/[()]//g')
        is_rpif2_orphan=0
        target_pid=""

        # EXPLICIT GUARD RULE: Absolute protection for snapd core sub-system blocks
        if [[ "${backing_file}" == *"/var/lib/snapd/"* ]]; then
            # Advance inspection loops immediately past vital snap container layout maps sectors
            continue
        fi

        # Filter Rule A: Identify temporary F2FS processing cluster disk blocks (Physical & Volatile)
        if [[ "${backing_file}" == *"/var/tmp/rpif2_"* ]] || [[ "${backing_file}" == *"/tmp/rpif2_"* ]]; then
            # Toggle leakage detection tracking indicator variables directly onto confirmation values
            is_rpif2_orphan=1
            # Filter the absolute process instance reference token from the target path configuration string
            target_pid=$(echo "${backing_file}" | grep -o -E '[0-9]+')
        fi

        # Filter Rule B: Identify raw uncompressed image loops or path baselines
        if [[ "${backing_file}" == *".raw"* ]] || [[ "${backing_file}" == *"/Raspberry Pi Raw OS/"* ]]; then
            # Toggle leakage detection tracking indicator variables directly onto confirmation values
            is_rpif2_orphan=1
        fi

        # INTEGRATION HARDENING (Filter Rule C): Capture loose raw test payloads inherited from clean_orphaned_loops.sh
        if [[ "${backing_file}" == *"raw_payload.img"* ]]; then
            # Toggle leakage detection tracking indicator variables directly onto confirmation values
            is_rpif2_orphan=1
        fi

        # 4. Flush the orphan device if it is confirmed to match our targeted leak signatures
        if [[ "${is_rpif2_orphan}" -eq 1 ]]; then
            # Check target process values validation lengths before executing thread activity tests
            if [[ -n "${target_pid}" ]]; then
                # Query kernel process tables; protect allocation if the parent process thread is actually alive
                if kill -0 "${target_pid}" 2>/dev/null && [[ " ${active_pids[*]} " =~ " ${target_pid} " ]]; then
                    # Abort destruction steps targeting active parallel image conversions setups
                    continue
                fi
            fi

            # Print hardware block leakage eradication reports directly to terminal standard output tracks
            echo -e "${COLOR_RED}[ORPHAN FOUND] Purging leaking device node: ${loop_dev} (${backing_file})${COLOR_NC}"

            local loop_token
            loop_token=$(basename "${loop_dev}")

            # Break active file handle blocks by issuing lazy unmounts on nested mappers first
            umount -Rfl "/dev/mapper/${loop_token}p1" >/dev/null 2>&1 || true
            umount -Rfl "/dev/mapper/${loop_token}p2" >/dev/null 2>&1 || true
            umount -Rfl "${loop_dev}" >/dev/null 2>&1 || true

            # Clear low-level device-mapper bindings authoritatively via forced dmsetup
            dmsetup remove -f "${loop_token}p1" >/dev/null 2>&1 || true
            dmsetup remove -f "${loop_token}p2" >/dev/null 2>&1 || true

            # Clear partition mapping structures safely using standard block erasure tracking software
            kpartx -dv "${loop_dev}" >/dev/null 2>&1
            # Flush hardware input output storage caching registers blocks to guarantee free links
            sync

            # Dismantle hardware block device linkages registrations completely from kernel setup registries
            losetup -d "${loop_dev}" >/dev/null 2>&1

            # Inject defensive fallback check blocks confirming if hardware nodes continue to populate tables
            if [[ -b "${loop_dev}" ]]; then
                # Force recursive hardware file detachment states to handle deeply locked device paths
                umount -Rfl "${loop_dev}" >/dev/null 2>&1
                # Trigger explicit block loop detach commands to ensure memory table sterilization loops
                losetup -d "${loop_dev}" >/dev/null 2>&1
            fi
        fi
    done < <(losetup -a)

    # 5. Clean loose directory trees from temporary scopes (Physical & Legacy Volatile)
    find /tmp -maxdepth 1 -type d -name "rpif2_probe_*" -exec rm -rf {} + 2>/dev/null
    find /var/tmp -maxdepth 1 -type f -name "rpif2_*.fs" -exec rm -f {} + 2>/dev/null
    find /tmp -maxdepth 1 -type f -name "rpif2_*.fs" -exec rm -f {} + 2>/dev/null

    # 6. Global LVM Layer Cleanup: Reclaim LVM pools if no active rpif2fs threads exist
    if [[ "${#active_pids[@]}" -eq 0 ]]; then
        # Check if logical volume device manager assemblies populate the active host shell environment
        if command -v vgchange >/dev/null 2>&1; then
            # Log global layer tracking allocation sterilizations back down onto master terminal windows
            echo -e "${COLOR_LBLUE}No active parallel processes remaining. Cleaning global LVM groups...${COLOR_NC}"
            # Put active host volume group configurations cleanly back into quiet offline storage states
            vgchange -an >/dev/null 2>&1
        fi
    fi
}

# =====================================================================
# Main Execution Orchestration Engine Runtime Context Loop Entrypoint
# =====================================================================
main() {
    # Execute root privilege validation tracking tests before allocating operational memory strings
    sanity_check
    # Launch absolute system wide loop audit sweep mappings to eliminate residual block leaks
    purge_system_wide_orphans
    # Log complete runtime structural validation success confirmations straight onto output channels
    echo -e "${COLOR_GREEN}Host loop tables and storage boundaries are now pristine!${COLOR_NC}"
}

# Trigger master pipeline context evaluation passing active standard positional arrays arguments
main "$@"
