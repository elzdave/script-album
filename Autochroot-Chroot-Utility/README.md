# Autochroot: Universal Automated Inline Cross-Architecture Chroot Utility

A professional-grade, universal, automated inline cross-architecture chroot utility for Linux system administration.

`autochroot` eliminates the manual overhead and human error associated with mounting broken systems, foreign architectures, or embedded disk images for recovery and debugging. Instead of relying on hardcoded partition numbers, it empirically probes block devices to locate the true Linux root mapping (`/`), dynamically handles sub-mount points via `/etc/fstab` footprints, and sets up QEMU user static emulation transparently.

---

## Key Features

- **Empirical Root Probing:** Dynamic signature detection for `ext2/3/4`, `f2fs`, `xfs`, and `btrfs` without hardcoded partition assumptions.
- **Proactive Fail-Safe Verification:** Built-in safeguards to intercept execution attempts aimed at partitions or the running host operating system disk, aborting immediately to prevent system conflicts.
- **Automated Dependency Lifecycle:** Automatically detects host package manager environment (`apt`, `pacman`, `dnf`, `zypper`) and runs localized, non-interactive setup runs to satisfy architecture components seamlessly.
- **Hierarchical Subsystem Mapping:** Intelligently parses target `/etc/fstab` profiles to automatically map nested allocations (`/boot` always mounted prior to `/boot/efi`) preventing structural overlay blocking.
- **Robust Network Synchronization:** Employs explicit symlink dereferencing to map host domain servers (`resolv.conf`) cleanly bypassing broken systemd-resolved links inside environments.
- **Cross-Architecture Emulation:** Transparently configures `qemu-user-static` binaries to allow `x86_64` hosts to execute commands inside `ARM` or `AARCH64` environments.
- **Defensive Interrupt Traps:** Registers robust signal handlers (`EXIT`, `SIGINT`, `SIGTERM`, `SIGHUP`) to guarantee automatic, lazy, and safe unmounting in reverse hierarchy order.

---

## Dependencies & Requirements

Core system utilities (`lsblk`, `mount`, `chroot`, `grep`, `findmnt`) are required to be present on the host distribution. Cross-architecture emulators (`qemu-user-static`, `binfmt-support`) will be **automatically installed** by the script during the runtime initialization pipeline.

---

## Installation

To configure `autochroot` as a globally available system utility, you can create a symbolic link directly to your system binaries directory:

```bash
sudo chmod 750 /path/to/this/autochroot
sudo ln -s /path/to/this/autochroot /usr/local/bin/autochroot
```

Alternatively, copy the file directly:

```bash
sudo cp autochroot /usr/local/bin/autochroot
sudo chmod 750 /usr/local/bin/autochroot
```

---

## How to Identify the Parent Block Device

Before running `autochroot`, you must correctly identify the **parent block device identifier** (e.g., `/dev/sdb` or `/dev/mmcblk0`) of your target storage media. Passing a specific partition identifier (like `/dev/sdb1`) will cause the probing sequence to fail.

Execute the following `lsblk` command on your host terminal to map connected storage block devices:

```bash
lsblk -p -o NAME,FSTYPE,SIZE,MODEL,MOUNTPOINTS
```

### Identification Guidelines:

1. **Match Capacity & Model:** Locate your target device (SD Card, USB flash drive, or external NVMe/SSD) by verifying its total storage capacity under the `SIZE` column and manufacturer hardware description under `MODEL`.
2. **Select the Top-Level Parent:** Choose the root storage disk path. Do **NOT** select sub-nodes that contain trailing partition numbers or partition layout symbols (└─ or ├─).

### Example Output Analysis:

```
NAME             FSTYPE   SIZE MODEL          MOUNTPOINTS
/dev/sda                223.6G Crucial_CT240
├─/dev/sda1      vfat     512M                /boot/efi
└─/dev/sda2      ext4   223.1G                /
/dev/sdb                 29.7G SD_Card_Reader
├─/dev/sdb1      vfat     512M
└─/dev/sdb2      f2fs     29.2G
```

- In the scenario mapped above, `/dev/sda` is your host OS drive.
- `/dev/sdb` represents the target pluggable storage media. The correct parent block device string to supply as an argument is **`/dev/sdb`** (Not `/dev/sdb1` or `/dev/sdb2`).

---

## Usage

Always execute `autochroot` with root privileges (`sudo`), pointing it to the parent block device of the target storage.

### Command Syntax

```bash
sudo autochroot <parent_block_device>
```

### Practical Examples

```bash
# Chroot into an SD card / NVMe drive containing Raspberry Pi OS or any Linux distro
sudo autochroot /dev/mmcblk0
sudo autochroot /dev/sdb
```

---

## Architecture Flow

```
[Host System] ──> Run: sudo autochroot /dev/sdb
                      │
                      ├── 1. Verify Root Privilege
                      ├── 2. Detect Host PKG Manager & Auto-Install Missing Emulators
                      ├── 3. Enforce Failsafes (Block host drives and partition nodes)
                      ├── 4. Probe partitions read-only to find /etc & /bin signatures
                      ├── 5. Mount true RootFS to /mnt/universal_root
                      ├── 6. Read internal fstab -> Mount /boot then /boot/efi sequentially
                      ├── 7. Bind virtual filesystems (/dev, /proc, /sys, /run)
                      ├── 8. Inject dereferenced DNS profile & QEMU static emulators
                      ├── 9. Hand over TTY control (fallback execution /bin/bash or /bin/sh)
                      │
 [Active Session] ────┼──> *Perform your debugging or script execution here*
                      │
    [Exit/Abort] ─────┴──> Trigger Traps ──> Lazy Unmount in reverse order ──> Safe to Eject
```

---

## Safety & Recovery Design

> **Defensive Engineering Note:** `autochroot` implements aggressive fail-safe barriers. If a user mistakenly inputs the system's own drive or a sub-partition node, execution is halted immediately prior to initializing the mount phases. Additionally, if an active session is interrupted via `Ctrl+C` or a terminal closure, defensive `trap` mechanics safely walk backward through the mount stack to guarantee the integrity of your target media.
