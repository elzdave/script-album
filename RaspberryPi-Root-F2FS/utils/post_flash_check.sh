#!/bin/bash

# =====================================================================
# post_flash_check.sh : Automated Post-Flashing F2FS Integration Auditor
# =====================================================================
# Description       : Audits targeted operating system metrics inside chroot or
#                     live boundaries to verify successful F2FS expansion.
#                     Detects the runtime environment context dynamically and
#                     strips ANSI color escape sequences from the final report.
# Style Standard    : Google Bash Scripting Guide & Defensive Engineering
# Usage             : sudo bash post_flash_check.sh
# Author            : David Eleazar
# Year              : 2026
# =====================================================================

# Enforce strict pipeline failure checks to prevent hidden execution bugs
set -o pipefail

# --- ANSI Terminal Functional Color Escape Sequences (Read-Only Constants) ---
readonly COLOR_NC='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_LBLUE='\033[1;34m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_YELLOW='\033[0;33m'

# --- Global Systems Configuration Constants (Immutable State) ---
readonly LOG_FILE="$(pwd)/post_flash_diagnostic.log"
readonly SEPARATOR="======================================================="

# --- Runtime Variable Trackers (Google Style Guide Lowercase Compliance) ---
start_time=0                # Benchmark tracking execution entry anchor
end_time=0                  # Benchmark tracking execution finish anchor

# =====================================================================
# Function    : verify_administrative_privileges
# Description : Enforces strict root permissions context boundary checks.
# Arguments   : None
# =====================================================================
verify_administrative_privileges() {
    echo -e "${COLOR_LBLUE}Sanity checking administrative context environment . . .${COLOR_NC}"

    if [[ "$(id -u)" != "0" ]]; then
        echo -e "${COLOR_WHITE}Usage: sudo bash post_flash_check.sh${COLOR_NC}"
        echo -e "${COLOR_RED}ERROR: Root access denied. Please re-run with sudo privileges.${COLOR_NC}"
        exit 1
    fi

    echo -e "${COLOR_GREEN}Execution context is verified as root.${COLOR_NC}"
}

# =====================================================================
# Function    : detect_execution_environment
# Description : Dynamically checks if the script is running inside a chroot 
#               environment or running natively on live target hardware via SSH.
# Arguments   : None
# =====================================================================
detect_execution_environment() {
    # Check inode or systemd virtual tokens to isolate true running state
    if [[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]] || [[ -f /..chroot_init ]]; then
        echo -e "${COLOR_YELLOW}[NOTICE] Script is running inside a CHROOT boundary.${COLOR_NC}"
        echo -e "${COLOR_YELLOW}--> Metrics like /proc/cmdline and df capacity reflect the HOST PC.${COLOR_NC}"
    else
        echo -e "${COLOR_GREEN}[INFO] Script is running natively on a LIVE TARGET system (SSH/Local).${COLOR_NC}"
    fi
}

# =====================================================================
# Function    : initialize_diagnostic_log
# Description : Prepares a clean structured file frame header for logging metrics.
# Arguments   : None
# =====================================================================
initialize_diagnostic_log() {
    echo "=== rpif2fs Post-Flashing F2FS Integration Audit Log ===" > "${LOG_FILE}"
    echo "Generated Timestamp : $(date)" >> "${LOG_FILE}"
    echo -e "${SEPARATOR}\n" >> "${LOG_FILE}"
}

# =====================================================================
# Function    : log_base_configuration_footprints
# Description : Captures standard system runtime parameters for environmental sanity.
# Arguments   : None
# =====================================================================
log_base_configuration_footprints() {
    echo -e "${COLOR_LBLUE}[*] Capturing target platform structural records . . .${COLOR_NC}"

    echo -e "--- Target /proc/cmdline Heuristics ---\n" >> "${LOG_FILE}"
    cat /proc/cmdline >> "${LOG_FILE}" 2>&1
    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"

    echo -e "--- Target File System Table (/etc/fstab) Layout ---\n" >> "${LOG_FILE}"
    cat /etc/fstab >> "${LOG_FILE}" 2>&1
    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"

    echo -e "--- Active Mount Point Details (findmnt) ---\n" >> "${LOG_FILE}"
    findmnt / >> "${LOG_FILE}" 2>&1
    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"
}

# =====================================================================
# Function    : evaluate_storage_expansion_discrepancy
# Description : Calculates partition allocations against verified active system 
#               file sizes to detect unexpanded geometry faults.
# Arguments   : None
# =====================================================================
evaluate_storage_expansion_discrepancy() {
    echo -e "${COLOR_LBLUE}[*] Auditing block geometric capacity maps . . .${COLOR_NC}"

    echo -e "--- Raw Hardware Partition Block Allocations (lsblk) ---\n" >> "${LOG_FILE}"
    lsblk >> "${LOG_FILE}" 2>&1
    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"

    echo -e "--- Active Filesystem Metric Volumetric Layouts (df) ---\n" >> "${LOG_FILE}"
    df -h / >> "${LOG_FILE}" 2>&1
    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"

    # Extract internal telemetry values dynamically using universal findmnt sweeps
    local root_dev
    local partition_block_size
    local filesystem_block_size

    root_dev=$(findmnt -no SOURCE / 2>/dev/null)
    partition_block_size=$(lsblk -no SIZE -d "${root_dev}" 2>/dev/null | tr -d '[:space:]')
    filesystem_block_size=$(df -h / --output=size | tail -n1 | tr -d '[:space:]')

    echo -e "--- Storage Expansion Automated Synthesis Verdict ---" >> "${LOG_FILE}"
    echo "Identified Live Root Block Node Path         : ${root_dev}" >> "${LOG_FILE}"
    echo "Physical Hardware Drive Partition Capacity   : ${partition_block_size}" >> "${LOG_FILE}"
    echo "Logical Storage System Filesystem Capacity   : ${filesystem_block_size}" >> "${LOG_FILE}"
    echo "Status Indication: If sizes diverge heavily, F2FS resize sequence triggered a fault." >> "${LOG_FILE}"
    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"
}

# =====================================================================
# Function    : audit_ramdisk_f2fs_footprint
# Description : Dynamically switches inspectors between Dracut and Initramfs-tools
#               to accurately verify internal asset payload generation mappings.
# Arguments   : None
# =====================================================================
audit_ramdisk_f2fs_footprint() {
    echo -e "${COLOR_LBLUE}[*] Analyzing local ramdisk target image archives . . .${COLOR_NC}"
    echo -e "--- Ramdisk Asset Packaging Internal Audit ---" >> "${LOG_FILE}"

    local targeted_ramdisk=""
    if [[ -f "/boot/initrd.img" ]]; then
        targeted_ramdisk="/boot/initrd.img"
    elif [[ -f "/boot/initramfs8" ]]; then
        targeted_ramdisk="/boot/initramfs8"
    elif [[ -f "/boot/firmware/initrd.img" ]]; then
        targeted_ramdisk="/boot/firmware/initrd.img"
    elif [[ -f "/boot/firmware/initramfs8" ]]; then
        targeted_ramdisk="/boot/firmware/initramfs8"
    fi

    if [[ -z "${targeted_ramdisk}" ]]; then
        echo "CRITICAL ERROR: No operational system ramdisk images discovered in boot maps." >> "${LOG_FILE}"
        echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"
        return 1
    fi

    echo "Inspecting Target Object: ${targeted_ramdisk}" >> "${LOG_FILE}"

    if command -v lsinitramfs >/dev/null 2>&1; then
        echo "Selected Audit Engine Tool: Debian lsinitramfs" >> "${LOG_FILE}"
        lsinitramfs "${targeted_ramdisk}" | grep -E 'f2fs|parted|resize|sed|findfs|blkid' >> "${LOG_FILE}" 2>&1 || true
    elif command -v lsinitrd >/dev/null 2>&1; then
        echo "Selected Audit Engine Tool: Enterprise Dracut lsinitrd" >> "${LOG_FILE}"
        lsinitrd "${targeted_ramdisk}" | grep -E 'f2fs|parted|resize|sed|findfs|blkid' >> "${LOG_FILE}" 2>&1 || true
    else
        echo "WARNING Toolchain Deprivation: Neither lsinitramfs nor lsinitrd are active inside this container environment." >> "${LOG_FILE}"
    fi

    echo -e "\n${SEPARATOR}\n" >> "${LOG_FILE}"
}

# =====================================================================
# Function    : aggregate_available_system_journals
# Description : Aggregates runtime boot logs across multiple subsystem 
#               channels (Journald, Dmesg, Syslog) concurrently. 
#               Explicitly removes arbitrary line truncation filters 
#               to ensure complete visibility of early-boot partition 
#               expansion steps.
# Arguments   : None
# =====================================================================
aggregate_available_system_journals() {
    echo -e "${COLOR_LBLUE}[*] Flushing available boot sequence log pipelines . . .${COLOR_NC}"
    echo -e "--- System Operational Boot Logs Auditing Context ---\n" >> "${LOG_FILE}"

    # --- Channel 1: Live Systemd Journal Engine ---
    # Captures structured systemd unit outputs and early boot logs safely
    if command -v journalctl >/dev/null 2>&1; then
        echo "--- Channel 1: Runtime Live Systemd Journal Engine ---" >> "${LOG_FILE}"
        journalctl -b 0 | grep -E -i 'f2fs|expand|resize|dracut|pre-mount' >> "${LOG_FILE}" 2>&1 || echo "No matching transactions recorded in systemd journal space." >> "${LOG_FILE}"
        echo -e "\n" >> "${LOG_FILE}"
    fi

    # --- Channel 2: Raw Kernel Ring Buffer (Dmesg) ---
    # Essential fallback for Debian environments where logs are pushed to /dev/kmsg
    if command -v dmesg >/dev/null 2>&1; then
        echo "--- Channel 2: Raw Kernel Ring Buffer (Dmesg) ---" >> "${LOG_FILE}"
        dmesg | grep -E -i 'f2fs|expand|resize|parted' >> "${LOG_FILE}" 2>&1 || echo "No matching tokens found in kernel ring buffer." >> "${LOG_FILE}"
        echo -e "\n" >> "${LOG_FILE}"
    fi

    # --- Channel 3: Legacy Syslog File Stream ---
    # Preserves older distribution compatibility parameters where rsyslog remains active
    if [[ -f "/var/log/syslog" ]]; then
        echo "--- Channel 3: Legacy /var/log/syslog File Stream ---" >> "${LOG_FILE}"
        grep -E -i 'f2fs|expand|resize|parted|dracut' /var/log/syslog >> "${LOG_FILE}" 2>&1 || echo "No custom F2FS signatures recorded inside syslog file bounds." >> "${LOG_FILE}"
        echo -e "\n" >> "${LOG_FILE}"
    fi

    # --- Defensive Guard Check ---
    # Handles environment isolation scenarios where all logging sub-systems are hidden
    if ! command -v journalctl >/dev/null 2>&1 && ! command -v dmesg >/dev/null 2>&1 && [[ ! -f "/var/log/syslog" ]]; then
        echo "NOTICE: All core logging subsystems are completely inaccessible within this environment context." >> "${LOG_FILE}"
    fi

    echo -e "${SEPARATOR}\n" >> "${LOG_FILE}"
}

# =====================================================================
# Function    : sanitize_diagnostic_log
# Description : Cleans ANSI color artifacts from the finalized log document.
# Arguments   : None
# =====================================================================
sanitize_diagnostic_log() {
    local temp_log
    if [[ -f "${LOG_FILE}" ]]; then
        temp_log="${LOG_FILE}.tmp"
        if sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' "${LOG_FILE}" > "${temp_log}"; then
            mv "${temp_log}" "${LOG_FILE}"
        else
            rm -f "${temp_log}"
        fi
    fi
}

# =====================================================================
# Function    : report_performance_metrics
# Description : Computes total diagnostic running time metrics.
# Arguments   : None
# =====================================================================
report_performance_metrics() {
    end_time="$(date +%s)"
    local total_runtime=$((end_time - start_time))
    echo -e "${COLOR_GREEN}[+] Diagnostic evaluation complete. Consolidated results captured in:${COLOR_NC} ${COLOR_WHITE}${LOG_FILE}${COLOR_NC}"
    echo -e "${COLOR_GREEN}Audit execution speed duration: ${COLOR_WHITE}${total_runtime}s${COLOR_NC}"
}

# =====================================================================
# Main Execution Orchestrator Pipeline Runtime Context Loop Entrypoint
# =====================================================================
main() {
    start_time="$(date +%s)"

    verify_administrative_privileges
    detect_execution_environment
    initialize_diagnostic_log
    log_base_configuration_footprints
    evaluate_storage_expansion_discrepancy
    audit_ramdisk_f2fs_footprint
    aggregate_available_system_journals
    sanitize_diagnostic_log
    report_performance_metrics
}

# Safe standard argument routing direction
main "$@"
