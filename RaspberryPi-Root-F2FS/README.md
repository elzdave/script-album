# rpif2fs: Universal Raspberry Pi Live Image F2FS Converter & Toolchain

A hardened, automated toolchain designed to convert official Raspberry Pi Linux distribution images (Ext4/XFS) into highly optimized Flash-Friendly File System (F2FS) layouts. Features dynamic multi-distro ramdisk reconstruction, fully automated first-boot offline storage expansion hooks, and isolated workspace sandboxing.

---

## 📂 Directory Structure

```text
.
├── README.md                 # Project documentation and workflow guide
├── rpif2fs.sh                # Core universal live image F2FS converter script
├── benchmarks/
│   ├── benchmark.sh          # Hardened Performance, Memory & Size Benchmarking Engine
│   └── pre_bench_check.sh    # Pre-Benchmark Workspace Validation & Sanitizer
└── utils/
    ├── mass_pre_flash_check.sh   # Batch script pipeline manager for pre-flash checks
    ├── post_flash_check.sh       # Post-flashing integration and file system sizing auditor
    ├── pre_flash_check.sh        # Ramdisk F2FS feature capability inspector
    ├── rpi_clean.sh              # Forensics-level consolidated workspace purger
    └── ur.sh                     # Fault-tolerant automated workload orchestrator
```

---

## ⚡ Core Features

- **Multi-Framework Initramfs Packaging:** Auto-detects and injects early-boot expansion hook layers natively into both **Dracut** (RHEL/AlmaLinux/Rocky Linux/Fedora) and **Initramfs-Tools** (Debian/Ubuntu/Raspberry Pi OS) frameworks.
- **Automated First-Boot Expansion:** Eliminates standard resizing configuration utilities (`raspi-config`) in favor of an elegant, offline kernel-level pre-mount storage scaling routine using `parted` and `resize.f2fs`.
- **Cross-Architecture Compilations:** Leverages QEMU user-space static binary emulation inside isolated `chroot` structures to construct internal `f2fs-tools` dependencies directly on host setups lacking updated native target repositories.
- **Enterprise Hardening Safeguards:** Features native support for modern UEFI + GRUB2 Boot Loader Specification (BLS) configurations, alongside self-destructive transient `systemd` services to smoothly toggle SELinux permissions across early first-boot cycles.
- **Defensive Shell Architecture:** Strict pipeline propagation execution configurations (`set -euo pipefail`), mutual exclusion locks, flattened stream redirection matrices, and robust atomic signal wrappers targeting automatic rollback purges.

---

## 🛠️ Host Prerequisites & Supported Distributions

The toolchain features an automated heuristic engine designed to detect the host architecture's package manager and deploy missing dependencies non-interactively. The script explicitly supports host environments running on the following package management frameworks:

### Supported Package Managers & OS Families:

- **APT Framework:** Debian, Ubuntu, Raspberry Pi OS, and derivatives (automatically triggers `apt-get update` before package provisioning).
- **DNF Framework:** Fedora, modern RHEL ecosystems, and RHEL-clones (AlmaLinux 10+, Rocky Linux 10+).
- **YUM Framework:** Legacy enterprise environments and older RHEL/CentOS streams.

### Dependency Mapping Automation:

The core script (`rpif2fs.sh`) automatically resolves package naming discrepancies between OS families during execution (e.g., dynamically mapping and installing `xz-utils` on Debian/APT hosts vs `xz` on RedHat/DNF/YUM hosts).

Before execution, ensure your host system provides administrative (`sudo`) privileges and active internet access. The toolchain will automatically evaluate and provision the following essential utilities if absent:

- `xz-utils` / `xz` (Multi-threaded stream compression)
- `f2fs-tools` (Filesystem building binaries)
- `kpartx` (Sector mapping block partition handlers)
- `lvm2` (Logical volume abstraction management)
- `rsync` (High-fidelity operational file replication mappings)
- `qemu-user-static` (Cross-platform architecture translation engine bridges)

---

## 💻 Hardware Specification Prerequisites

The toolchain executes intensive I/O data replication, filesystem building, and high-ratio multi-threaded compression. Pipeline execution requires compliance with the following hardware profiles:

### 1. Processor Architecture

- **x86_64 Host:** Supported out-of-the-box. The toolchain automatically fetches cross-compilation assets and maps `qemu-aarch64-static` to build internal target binaries inside isolated aarch64 chroot containers smoothly.
- **ARM64 / AArch64 Host:** Fully supported natively out-of-the-box. The architecture heuristic engine automatically detects the native environment (via `uname -m`) and dynamically bypasses QEMU user-static emulation requirements, executing compilation workflows directly on the physical cores with maximum native performance.

### 2. CPU Compute Allocation

- Minimum **2 Cores / 4 Threads**. The main runtime constraints throttle compilation and archiving streams strictly to 2 dedicated threads (`make -j2` and `xz -T2`) to safeguard kernel table mappings against thrashing.

### 3. Memory (RAM) Sizing

- Minimum **2 GB RAM**. The underlying multi-threaded high-efficiency compression algorithm is configured to use preset 5 (the safe industrial fallback standard), requiring an optimized overhead of only \~94 MB per core thread (\~188 MB exclusively for compression).

### 4. Storage Subsystem (Critical Bottleneck)

- **Drive Type:** **SSD (SATA or NVMe) is mandatory.** Mechanical Hard Disk Drives (HDDs) are heavily discouraged due to extreme I/O wait latencies during deep sector extraction, asynchronous data synchronization via `rsync`, and compression phases.
- **Capacity Overhead:** Ensure a minimum of **30 GB to 40 GB** of free capacity. This allocation must be **completely free** within the `/var/tmp` partition (shared between the temporary `.fs` loop staging layers for the converter and the raw `.img` extraction workspaces for the pre-flash inspector) as well as the source image directory, since modern Linux hosts isolate the volatile `/tmp` directory inside RAM-backed `tmpfs`.

---

## 📖 Component Manifest & Usage

### 🚀 Quick Start: Granting Execution Permissions

Before executing any component within this toolchain, ensure that all shell scripts are granted proper execution permissions across your environment:

```bash
sudo chmod 750 rpif2fs.sh utils/*.sh benchmarks/*.sh
```

### 1. Main Conversion Core (`rpif2fs.sh`)

The execution engine of the toolchain. It decompresses the `.img.xz` target, maps raw boundaries using loop controllers, stages filesystem transfers into transient containers, compiles system dependencies, injects the expansion hooks, rebuilds the target ramdisk, and wraps the outputs back into localized multi-threaded distributions.

```bash
# Usage via explicit command line argument:
sudo bash rpif2fs.sh "/path/to/image.img.xz"

# Usage via interactive GUI fallback (Zenity/KDialog):
sudo bash rpif2fs.sh
```

### 2. Advanced Ramdisk Inspectors (`utils/pre_flash_check.sh` & `utils/mass_pre_flash_check.sh`)

Before flashing the newly constructed images to SD Cards or NVMe blocks, these components inspect deep compressed multi-layer `cpio` archives inside the target initialization ramdisk binary (`initramfs8` or `initrd.img`) to check for required expansion hooks, binaries, and `f2fs.ko` drivers.

#### Single Image Verification:

```bash
sudo bash utils/pre_flash_check.sh "/path/to/image-f2fs.img.xz"
```

#### Batch Cluster Automation Workflow:

To automate verification for multiple images sequentially without modifying the master repository script, follow this decoupled workflow:

**Step 1: Copy the Baseline Batch Script**

```bash
cp utils/mass_pre_flash_check.sh utils/mass_pre_flash_check.sh.own
```

**Step 2: Populate Target Staging Paths**

Open `utils/mass_pre_flash_check.sh.own` in a text editor and modify the global, read-only `IMAGE_PATHS` array with the absolute paths of your generated F2FS images:

```bash
# Example modification within utils/mass_pre_flash_check.sh.own
readonly IMAGE_PATHS=(
    "/absolute/path/to/image1-f2fs.img.xz"
    "/absolute/path/to/image2-f2fs.img.xz"
)
```

**Step 3: Execute the Custom Batch Pipeline**

```bash
sudo bash utils/mass_pre_flash_check.sh.own
```

_Note: Clean, ANSI-stripped individual metrics tracks are mirrored to `pre_flash.*.log` files automatically via process substitution to ensure precise background PID tracking._

### 3. Post-Flashing Integration Auditor (`utils/post_flash_check.sh`)

A diagnostic post-installation health inspector. **This specific script must be transferred or copied directly onto the target environment before execution.** It compiles volume capacities, isolates hardware block divergence errors, audits local ramdisk symbols, and dumps systemic boot entries.

```bash
# Execute locally on the target device after copying:
sudo bash post_flash_check.sh
```

_Outputs structured validation traces inside `post_flash_diagnostic.log`._

### 4. Consolidated Workspace Purger (`utils/rpi_clean.sh`)

A forensics-level consolidated workspace and loop system state recovery script. If an execution pipeline drops via an unhandled system crash or termination interrupt, this utility sweeps the active kernel table, disconnects dangling device-mappers, safely unlocks image bindings, flushes raw payload images, and tears down memory loops while strictly shielding independent infrastructure items (e.g., `snapd`).

```bash
# Comprehensive forensic scan and purge:
sudo bash utils/rpi_clean.sh
```

### 5. Isolated Performance Benchmarking Suite (`benchmarks/`)

A dedicated verification matrix framework to profile `rpif2fs.sh` behavior across LZMA2 compression presets (0-9). To execute the benchmarking matrices securely without disturbing master repository structures, execute the following three-step decoupled workflow:

#### Step 1: Copy the Baseline Configuration

Generate a private local benchmark orchestration file to encapsulate your current workload definitions:

```bash
cp benchmarks/benchmark.sh benchmarks/benchmark.sh.own
```

#### Step 2: Populate the Target Workloads

Open `benchmarks/benchmark.sh.own` in your preferred text editor and modify the global, read-only `IMAGES` tracking array with the absolute path(s) of the original compressed image files scheduled for testing:

```bash
# Example modification within benchmarks/benchmark.sh.own
readonly IMAGES=(
    "/absolute/path/to/original_image1.img.xz"
    "/absolute/path/to/original_image2.img.xz"
)
```

#### Step 3: Run Validation and Execution Gates

Always perform the system-wide validation check to confirm storage overhead constraints before firing the profiling engine. If the validation reporting logs return success, proceed to execute your customized benchmarking sequence:

```bash
# 1. Run the pre-benchmark workspace validation and deep health audit:
sudo bash benchmarks/pre_bench_check.sh

# 2. If status reports OK, launch the automated benchmarking engine matrix loops:
sudo bash benchmarks/benchmark.sh.own
```

---

## 🛡️ Defensive Engineering Design Principles

- **Asynchronous Anti-Collision Delay:** Features randomized decimal micro-jitter desynchronization routines during block attachment maps to prevent race condition collisions against active kernel threads (`udevd`).
- **Private Mount Namespace Propagation:** Forces `--make-private` flag attachments to prevent bind-mounted system trees (`/dev`, `/proc`, `/sys`) from permanently bleeding structures back into the primary host platform namespace.
- **Strict Locale Configuration Hardening:** Enforces `LC_NUMERIC=C` constraints natively across subshell executions to ensure uniform floating-point decimal parsing during sleep segments, eliminating evaluation failures on internationalized host configurations.
- **LIFO Teardown Traps:** Implements Last-In, First-Out operational tracking arrays bound directly onto signal wrappers (`EXIT`, `INT`, `TERM`) to guarantee structural de-allocation of hardware device mappings during unexpected critical runtime failures.
