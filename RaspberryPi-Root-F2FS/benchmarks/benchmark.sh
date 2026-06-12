#!/bin/bash

# =====================================================================
# benchmark.sh : Hardened Decoupled Performance & Memory Benchmarking Engine
# =====================================================================
# Description       : Automates rpif2fs testing across LZMA2 presets (0-9) inside
#                     a sandboxed /var/tmp workspace. Dynamically generates task
#                     manifests and offloads parallel execution to the universal
#                     orchestrator (ur.sh) via environment injection.
# Style Standard    : Google Bash Scripting Guide & Defensive Engineering
# Usage             : sudo bash benchmarks/benchmark.sh
# Author            : David Eleazar
# Year              : 2026
# =====================================================================

# Enforce strict pipeline failure checks to optimize error tracking.
set -euo pipefail
IFS=$'\n\t'

# --- Path Discovery Context (Ensures resilience regardless of invocation source) ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# --- Decoupled Target Orchestrator Configuration ---
readonly UR_SCRIPT_PATH="utils/ur.sh"

# --- Core Performance Constants ---
readonly RPIF2FS_SCRIPT="rpif2fs.sh"
readonly RPIF2FS_BACKUP="rpif2fs.sh.bak"
readonly REPORT_FILE="benchmarks/benchmark_report.txt"
readonly BENCH_WORKSPACE="/var/tmp/rpif2fs_bench_workspace"
readonly TEMP_TASK_FILE="/var/tmp/ur_rpif2fs_tasks.txt"
readonly BENCH_SESSION_NAME="rpif2fs_bench_session"

# --- Target Image Asset Registration ---
readonly IMAGES=(
    # "/absolute/path/to/image1.*.xz"
    # "/absolute/path/to/image2.*.xz"
    # "/absolute/path/to/image3.*.xz"
    # "/absolute/path/to/image4.*.xz"
    # "/absolute/path/to/image5.*.xz"
)

# --- Dynamic Ownership & Permission Trackers (Mitigates root-takeover) ---
ORIG_RPIF2FS_OWNER=""
ORIG_RPIF2FS_PERM=""
ORIG_SCRIPT_OWNER=""

# =====================================================================
# Function    : navigate_to_project_root
# Description : Shifts execution context directly to the project root directory.
# Arguments   : None
# =====================================================================
navigate_to_project_root() {
    cd "${PROJECT_ROOT}"
}

# =====================================================================
# Function    : perform_sanity_checks
# Description : Enforces root privileges and verifies mandatory binaries,
#               explicitly checking for GNU time and the decoupled ur.sh core.
# Arguments   : None
# =====================================================================
perform_sanity_checks() {
    if [[ "$(id -u)" != "0" ]]; then
        echo "ERROR: Root access denied. Please run this benchmark utility as root (sudo)." >&2
        exit 1
    fi

    if [[ ! -f "${RPIF2FS_SCRIPT}" ]]; then
        echo "ERROR: Core script '${RPIF2FS_SCRIPT}' missing from project root directory." >&2
        exit 1
    fi

    if [[ ! -f "${UR_SCRIPT_PATH}" ]]; then
        echo "ERROR: Decoupled universal orchestrator missing at: ${UR_SCRIPT_PATH}" >&2
        exit 1
    fi

    if [[ ! -x "/usr/bin/time" ]]; then
        echo "ERROR: Mandatory GNU time binary (/usr/bin/time) is missing!" >&2
        exit 1
    fi

    if [[ ${#IMAGES[@]} -eq 0 ]]; then
        echo "ERROR: Target IMAGES array is empty. Define target files inside benchmark.sh." >&2
        exit 1
    fi
}

# =====================================================================
# Function    : capture_original_file_metadata
# Description : Preserves original owner and permission flags for rollbacks.
# Arguments   : None
# =====================================================================
capture_original_file_metadata() {
    ORIG_RPIF2FS_OWNER=$(stat -c '%u:%g' "${RPIF2FS_SCRIPT}")
    ORIG_RPIF2FS_PERM=$(stat -c '%a' "${RPIF2FS_SCRIPT}")
    ORIG_SCRIPT_OWNER=$(stat -c '%u:%g' "${SCRIPT_DIR}/benchmark.sh")
}

# =====================================================================
# Function    : initialize_report_file
# Description : Prepares a clean structured header for the benchmark report.
# Arguments   : None
# =====================================================================
initialize_report_file() {
    echo "=======================================================================" > "${REPORT_FILE}"
    echo "       RPIF2FS ISOLATED WORKSPACE PERFORMANCE REPORT                   " >> "${REPORT_FILE}"
    echo "=======================================================================" >> "${REPORT_FILE}"
    echo "Generated Timestamp : $(date)" >> "${REPORT_FILE}"
    echo "Isolated Workspace  : ${BENCH_WORKSPACE}" >> "${REPORT_FILE}"
    echo -e "=======================================================================\n" >> "${REPORT_FILE}"

    if [[ -n "${ORIG_SCRIPT_OWNER}" ]]; then
        chown "${ORIG_SCRIPT_OWNER}" "${REPORT_FILE}"
    fi
}

# =====================================================================
# Function    : setup_sandbox_workspace
# Description : Allocates the sandboxed partition workspace and stages copied assets.
# Arguments   : None
# =====================================================================
setup_sandbox_workspace() {
    echo "[INFO] Allocating isolated storage workspace bounds inside /var/tmp . . ."
    rm -rf "${BENCH_WORKSPACE}"
    mkdir -p "${BENCH_WORKSPACE}"

    local img
    for img in "${IMAGES[@]}"; do
        if [[ ! -f "${img}" ]]; then
            echo "ERROR: Source target image file not found on physical drive: ${img}" >&2
            exit 1
        fi
        echo "  -> Copying $(basename "${img}") to sandbox storage area . . ."
        cp "${img}" "${BENCH_WORKSPACE}/"
    done
    echo -e "[SUCCESS] Storage sandbox workspace successfully initialized.\n"
}

# =====================================================================
# Function    : instrument_core_script
# Description : Injects GNU time hooks into the target conversion script.
# Arguments   : None
# =====================================================================
instrument_core_script() {
    cp -p "${RPIF2FS_SCRIPT}" "${RPIF2FS_BACKUP}"

    sed -i -E 's|xz[[:space:]]+-zfv[^[:space:]]+|/usr/bin/time -f "XZ Peak Memory Usage: %M KB" &|g' "${RPIF2FS_SCRIPT}"
    sed -i -E 's|umount[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*.*probe_dir.*|umount -fl "${probe_dir}" 2>/dev/null \|\| true|g' "${RPIF2FS_SCRIPT}"

    chown "${ORIG_RPIF2FS_OWNER}" "${RPIF2FS_SCRIPT}"
    chmod "${ORIG_RPIF2FS_PERM}" "${RPIF2FS_SCRIPT}"
}

# =====================================================================
# Function    : generate_task_manifest
# Description : Dynamically writes target workloads into a flat manifest file.
# Arguments   : None
# =====================================================================
generate_task_manifest() {
    true > "${TEMP_TASK_FILE}"
    
    local source_img
    for source_img in "${IMAGES[@]}"; do
        echo "bash ${PROJECT_ROOT}/${RPIF2FS_SCRIPT} '${BENCH_WORKSPACE}/$(basename "${source_img}")'" >> "${TEMP_TASK_FILE}"
    done
}

# =====================================================================
# Function    : aggregate_iteration_metrics
# Description : Parses logged outputs to compile execution telemetry.
# Arguments   : $1 - The current compression preset level evaluated
# =====================================================================
aggregate_iteration_metrics() {
    local preset="$1"
    local log_file=""
    local img_name=""
    local exec_time=""
    local mem_usage=""
    local out_path=""
    local file_size=""
    local orig_size=""
    local archive_dir=""

    echo "--- PRESET LEVEL ${preset} PERFORMANCE METRICS ---" >> "${REPORT_FILE}"
    archive_dir="benchmarks/benchmark_results/preset_${preset}"
    mkdir -p "${archive_dir}"

    if ls logs/rpif2fs_*_conversion.log >/dev/null 2>&1; then
        for log_file in logs/rpif2fs_*_conversion.log; do
            if [[ -f "${log_file}" ]]; then
                img_name=$(basename "${log_file}" _conversion.log | sed 's/rpif2fs_//')
                
                exec_time=$(grep "Total Execution Time:" "${log_file}" | sed 's/.*Total Execution Time://' | xargs -r || echo "N/A")
                mem_usage=$(grep "XZ Peak Memory Usage:" "${log_file}" | sed 's/.*XZ Peak Memory Usage://' | xargs -r || echo "N/A")
                out_path=$(grep "Output distribution ready build path location:" "${log_file}" | sed 's/.*Output distribution ready build path location://' | xargs || echo "")
                
                orig_size="N/A"
                if [[ -f "${BENCH_WORKSPACE}/${img_name}.xz" ]]; then
                    orig_size=$(du -sh "${BENCH_WORKSPACE}/${img_name}.xz" | awk '{print $1}')
                fi

                file_size="N/A"
                if [[ -n "${out_path}" && -f "${out_path}" ]]; then
                    file_size=$(du -sh "${out_path}" | awk '{print $1}')
                    rm -f "${out_path}"
                fi
                
                echo "  - Image: ${img_name}" >> "${REPORT_FILE}"
                echo "    [Time: ${exec_time}] [Peak RAM: ${mem_usage}] [Original Size: ${orig_size}] [Compressed Size: ${file_size}]" >> "${REPORT_FILE}"
            fi
        done
        mv logs/rpif2fs_*_conversion.log "${archive_dir}/"
    else
        echo "  - No operational conversion logs captured for this preset level." >> "${REPORT_FILE}"
    fi
    echo -e "-----------------------------------------------------------------------\n" >> "${REPORT_FILE}"

    if [[ -d "benchmarks/benchmark_results" && -n "${ORIG_SCRIPT_OWNER}" ]]; then
        chown -R "${ORIG_SCRIPT_OWNER}" "benchmarks/benchmark_results"
    fi
    if [[ -f "${REPORT_FILE}" && -n "${ORIG_SCRIPT_OWNER}" ]]; then
        chown "${ORIG_SCRIPT_OWNER}" "${REPORT_FILE}"
    fi
}

# =====================================================================
# Function    : execute_benchmark_matrix
# Description : Iterates presets 0-9, passes workload mandates to ur.sh via
#               environment isolation, and aggregates performance records.
# Arguments   : None
# =====================================================================
execute_benchmark_matrix() {
    instrument_core_script

    local preset=0
    for preset in {0..9}; do
        echo "======================================================="
        echo "STARTING BENCHMARK ITERATION: PRESET ${preset}"
        echo "======================================================="
        
        generate_task_manifest

        echo "[INFO] Invoking universal orchestrator via environment injection . . ."
        
        # Inject dynamic settings directly into ur.sh runtime boundaries.
        # State file journal is isolated per preset to secure independent recovery tracking.
        # UR_ATTACH="false" explicitly silences foreground terminal hijacking for headless automated loops.
        UR_EXEC_MODE="queue" \
        UR_MAX_PARALLEL=4 \
        UR_SESSION_NAME="${BENCH_SESSION_NAME}" \
        UR_STATE_FILE="benchmarks/.ur_journal_preset_${preset}.log" \
        UR_ENFORCE_ROOT="true" \
        UR_TASK_FILE="${TEMP_TASK_FILE}" \
        UR_ATTACH="false" \
        COMPRESSION_PRESET="${preset}" \
        bash "${UR_SCRIPT_PATH}"

        while tmux has-session -t "${BENCH_SESSION_NAME}" 2>/dev/null; do
            sleep 2
        done

        echo "[INFO] Iteration complete. Aggregating telemetry metrics . . ."
        aggregate_iteration_metrics "${preset}"

        find "${BENCH_WORKSPACE}" -type f -name "*-f2fs.*.xz" -exec rm -f {} +
        echo -e "[SUCCESS] Storage sterilized. Staging next preset matrix block.\n"
    done
}

# =====================================================================
# Function    : cleanup_workspace
# Description : Reverts script infrastructure back to pristine states and
#               completely vaporizes the temporary /var/tmp sandbox folder.
# Arguments   : None
# =====================================================================
cleanup_workspace() {
    echo -e "\n[ROLLBACK] Initiating global cleanup and script restoration..."
    
    if [[ -f "${RPIF2FS_BACKUP}" ]]; then
        mv "${RPIF2FS_BACKUP}" "${RPIF2FS_SCRIPT}"
    fi

    if [[ -f "${RPIF2FS_SCRIPT}" && -n "${ORIG_RPIF2FS_OWNER}" ]]; then
        chown "${ORIG_RPIF2FS_OWNER}" "${RPIF2FS_SCRIPT}"
        chmod "${ORIG_RPIF2FS_PERM}" "${RPIF2FS_SCRIPT}"
    fi

    if [[ -f "${REPORT_FILE}" && -n "${ORIG_SCRIPT_OWNER}" ]]; then
        chown "${ORIG_SCRIPT_OWNER}" "${REPORT_FILE}"
    fi
    
    if [[ -d "benchmarks/benchmark_results" && -n "${ORIG_SCRIPT_OWNER}" ]]; then
        chown -R "${ORIG_SCRIPT_OWNER}" "benchmarks/benchmark_results"
    fi

    rm -f "${TEMP_TASK_FILE}"

    if [[ -d "${BENCH_WORKSPACE}" ]]; then
        echo "[ROLLBACK] Vaporizing sandboxed workspace directory from /var/tmp . . ."
        rm -rf "${BENCH_WORKSPACE}"
    fi
    echo "[ROLLBACK] System cleanup complete. Infrastructure is pristine."
}

# =====================================================================
# Function    : establish_clean_traps
# Description : Registers emergency cleanup traps for standard interrupt signals.
# Arguments   : None
# =====================================================================
establish_clean_traps() {
    trap cleanup_workspace EXIT INT TERM
}

# =====================================================================
# Function    : print_completion_summary
# Description : Displays final pathing details for the compiled log report.
# Arguments   : None
# =====================================================================
print_completion_summary() {
    echo "======================================================================="
    echo "BENCHMARK COMPLETED SUCCESSFULLY! Consolidated metrics: ${REPORT_FILE}"
    echo "======================================================================="
}

# =====================================================================
# Main Execution Orchestrator Pipeline Runtime Context Entrypoint
# =====================================================================
main() {
    navigate_to_project_root
    perform_sanity_checks
    capture_original_file_metadata
    initialize_report_file
    setup_sandbox_workspace
    establish_clean_traps
    execute_benchmark_matrix
    print_completion_summary
}

main "$@"
