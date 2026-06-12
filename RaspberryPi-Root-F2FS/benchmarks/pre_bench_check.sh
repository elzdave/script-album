#!/bin/bash

# =====================================================================
# pre_bench_check.sh : Pre-Benchmark Workspace Validation & Sanitizer
# =====================================================================
# Description       : Audits host health, storage capacity, and toolchain integrity
#                     before benchmarking. Flushes latent block locks using
#                     utils/rpi_clean.sh and dynamically pivots to the project root.
# Style Standard    : Google Bash Scripting Guide & Defensive Engineering
# Usage             : sudo bash benchmarks/pre_bench_check.sh
# Author            : David Eleazar
# Year              : 2026
# =====================================================================

# Enforce strict pipeline failure checks to optimize error tracking.
set -euo pipefail
IFS=$'\n\t'

# --- Path Discovery Context (Ensures resilience regardless of invocation source) ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# --- Read-Only Global Constants (Relative to PROJECT_ROOT context) ---
readonly REQUIRED_SCRIPTS=("rpif2fs.sh" "benchmarks/benchmark.sh" "utils/ur.sh" "utils/rpi_clean.sh")
readonly MIN_FREE_SPACE_GB=30
readonly SESSION_NAME="rpif2fs_bench_session"
readonly TARGET_DIR="/var/tmp"

# --- ANSI Terminal Functional Color Escape Sequences ---
readonly COLOR_NC='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_LBLUE='\033[1;34m'
readonly COLOR_WHITE='\033[1;37m'

# =====================================================================
# Function    : navigate_to_project_root
# Description : Authoritatively pivots shell context directly onto project root.
# Arguments   : None
# =====================================================================
navigate_to_project_root() {
    cd "${PROJECT_ROOT}"
}

# =====================================================================
# Function    : print_welcome_banner
# Description : Displays the clinical environment verification banner.
# Arguments   : None
# =====================================================================
print_welcome_banner() {
    echo -e "${COLOR_YELLOW}=======================================================================${COLOR_NC}"
    echo -e "${COLOR_WHITE}       RPIF2FS TOOLCHAIN PRE-BENCHMARK HEALTH & ENVIRONMENT AUDIT      ${COLOR_NC}"
    echo -e "${COLOR_YELLOW}=======================================================================${COLOR_NC}"
}

# =====================================================================
# Function    : check_root_privileges
# Description : Enforces that the preparation wrapper runs under root context.
# Arguments   : None
# =====================================================================
check_root_privileges() {
    echo -e "${COLOR_LBLUE}[PRE-CHECK] Validating administrative root execution environment . . .${COLOR_NC}"
    if [[ "$(id -u)" != "0" ]]; then
        echo -e "${COLOR_RED}ERROR: Privilege validation failed. Please execute via sudo:${COLOR_NC}" >&2
        echo -e "${COLOR_RED}       sudo bash benchmarks/pre_bench_check.sh${COLOR_NC}" >&2
        exit 1
    fi
    echo -e "${COLOR_GREEN}[SUCCESS] Root execution privileges confirmed.${COLOR_NC}"
}

# =====================================================================
# Function    : verify_script_integrity
# Description : Audits the local directory structure to ensure all required
#               toolchain components are present and executable.
# Arguments   : None
# =====================================================================
verify_script_integrity() {
    echo -e "${COLOR_LBLUE}[PRE-CHECK] Auditing toolchain components integrity profiles . . .${COLOR_NC}"
    local script
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        if [[ ! -f "${script}" ]]; then
            echo -e "${COLOR_RED}ERROR: Mandatory toolchain component '${script}' is missing!${COLOR_NC}" >&2
            exit 1
        fi
        if [[ ! -x "${script}" ]]; then
            echo -e "${COLOR_YELLOW}[WARNING] Script '${script}' lacks execution permissions. Hardening now...${COLOR_NC}"
            chmod +x "${script}"
        fi
        echo -e "${COLOR_GREEN}  -> Component '${script}' verified and active.${COLOR_NC}"
    done
}

# =====================================================================
# Function    : intercept_active_sessions
# Description : Audits tmux system registers to check for conflicting runs.
# Arguments   : None
# =====================================================================
intercept_active_sessions() {
    echo -e "${COLOR_LBLUE}[PRE-CHECK] Scanning for conflicting active TMUX runtime contexts . . .${COLOR_NC}"
    if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
        echo -e "${COLOR_YELLOW}[CONFLICT] Active session '${SESSION_NAME}' detected!${COLOR_NC}"
        echo -n "Would you like to force-terminate the existing TMUX session? (y/N): "
        read -r user_response
        if [[ "${user_response}" =~ ^[Yy]$ ]]; then
            echo -e "${COLOR_RED}Force-killing active TMUX session grid system-wide . . .${COLOR_NC}"
            tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
            sync
            sleep 1
        else
            echo -e "${COLOR_RED}ERROR: Workspace preparation aborted to prevent mid-run corruption.${COLOR_NC}" >&2
            exit 1
        fi
    else
        echo -e "${COLOR_GREEN}[SUCCESS] No conflicting TMUX orchestrator workloads found.${COLOR_NC}"
    fi
}

# =====================================================================
# Function    : trigger_deep_cleanup
# Description : Executes rpi_clean.sh from the redirected utils subdirectory
#               to clear out latent loop devices and loose file mappers.
# Arguments   : None
# =====================================================================
trigger_deep_cleanup() {
    echo -e "${COLOR_LBLUE}[PRE-CHECK] Invoking rpi_clean.sh for deep kernel block device sterilization . . .${COLOR_NC}"
    if ! bash utils/rpi_clean.sh; then
        echo -e "${COLOR_RED}ERROR: Subsystem sanitation routine reported execution failures!${COLOR_NC}" >&2
        exit 1
    fi
}

# =====================================================================
# Function    : check_disk_capacity
# Description : Inspects free storage block metrics inside the staging 
#               partition to dynamically mitigate mid-run disk saturation.
# Arguments   : None
# =====================================================================
check_disk_capacity() {
    echo -e "${COLOR_LBLUE}[PRE-CHECK] Auditing physical storage workspace bounds capacity . . .${COLOR_NC}"
    local available_space_kb
    local available_space_gb
    
    available_space_kb=$(df -P "${TARGET_DIR}" | awk 'NR==2 {print $4}')
    available_space_gb=$((available_space_kb / 1024 / 1024))
    
    echo -e "${COLOR_WHITE}  -> Target Partition (${TARGET_DIR}) Available Space: ${available_space_gb} GB${COLOR_NC}"
    
    if [[ "${available_space_gb}" -lt "${MIN_FREE_SPACE_GB}" ]]; then
        echo -e "${COLOR_RED}ERROR: Insufficient disk space on ${TARGET_DIR}! Minimum required: ${MIN_FREE_SPACE_GB} GB.${COLOR_NC}" >&2
        echo -e "${COLOR_RED}       Please clear disk space before executing the benchmark pipeline.${COLOR_NC}" >&2
        exit 1
    fi
    echo -e "${COLOR_GREEN}[SUCCESS] Storage capacity metrics fall safely within defensive thresholds.${COLOR_NC}"
}

# =====================================================================
# Function    : print_success_summary
# Description : Renders final notification of target system readiness.
# Arguments   : None
# =====================================================================
print_success_summary() {
    echo -e "${COLOR_YELLOW}=======================================================================${COLOR_NC}"
    echo -e "${COLOR_GREEN}SUCCESS: Environment is pristine! Ready to execute benchmark.sh safely.${COLOR_NC}"
    echo -e "${COLOR_YELLOW}=======================================================================${COLOR_NC}"
}

# =====================================================================
# Main Execution Orchestrator Entrypoint
# =====================================================================
main() {
    navigate_to_project_root
    print_welcome_banner
    check_root_privileges
    verify_script_integrity
    intercept_active_sessions
    trigger_deep_cleanup
    check_disk_capacity
    print_success_summary
}

main "$@"
