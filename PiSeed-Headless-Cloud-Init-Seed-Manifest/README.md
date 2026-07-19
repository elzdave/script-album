# piseed.sh - Cloud-Init Manifest Generator for Raspberry Pi

`piseed.sh` is a lightweight standalone system administration utility designed to automate cluster deployments. It programmatically generates a synchronized 3-part cloud-init bundle (`user-data`, `meta-data`, and `network-config`) explicitly optimized for Raspberry Pi single-board computers running modern distributions such as **AlmaLinux 9/10** and **Raspberry Pi OS**.

---

## Key Features

1. **Dual-Layer Network Configuration**
   Ensures reliable Wi-Fi connections across different distribution types:
   - **Early Boot Stage (`network-config`):** Generates a Netplan Version 2 compliant configuration file for modern network configuration utilities.
   - **Runtime Fallback Stage (`user-data runcmd`):** Injects native NetworkManager execution rules via `nmcli` to force-provision endpoints if early stages are skipped.

2. **Time and Clock Synchronization Setup**
   Handles clock drifts during early initialization by using non-strict SSL handshakes (`curl -k`) while searching for upstream network routes. Falls back to `UTC` if local host metrics cannot be extracted.

3. **Unified Security System Support**
   Automates secure SHA-512 crypt-style account creation. Manages package ecosystem sync entries (`dnf`/`yum` vs `apt`), custom SSH port adjustments, configuration drop-ins (`sshd_config.d/`), socket isolation sweeps, and traditional multi-distro firewall platforms (`firewalld`/`ufw`).

4. **Cryptographic Key Collection**
   Automatically discovers and registers existing host workstation keys (`~/.ssh/` and `/etc/ssh/`) into user data configurations. Serializes existing offline hardware key structures from the workspace into early init blocks to mitigate identity spoofing risks.

5. **SELinux-Aware Lifecycles**
   Configures required workspace attributes (`semanage port`) and places validation stamps (`/.autorelabel`) to maintain file security structure integrity upon standard boots.

---

## Project Workspace Layout

```text
.
├── piseed.sh          # Configuration generator script
├── data.own.example   # Static reference configuration layout
├── data.own           # Active secrets file (User created, git-ignored)
├── README.md          # Project documentation and operational guide
└── ssh/               # Optional folder for pre-generated target host keys
    └── README.md      # Guide for generating and embedding host keys
```

---

## Operating Instructions

### Track A: Automated Processing (DevOps Strategy)

1. Clone the reference configuration template format to an active profile filename:

```bash
cp data.own.example data.own
```

2. Edit your system specifications (passwords, timeframes, targets) inside `data.own` according to your needs:

```ini
USERNAME=pi
PASSWORD=mysecurepassword123
SSH_PASSWORD_LOGIN=false
SSH_PORT=1234
HOSTNAME=RaspberryExMachina
WIFI_ENABLE=true
WIFI_SSID=My Home Network SSID
WIFI_PASSWORD=mysecretwifipassword
WIFI_REG_DOMAIN=GB
ENABLE_REBOOT=true
```

3. Run the generator script. The system automatically reads parameters from `data.own`, skips the prompts, and updates data streams:

```bash
bash piseed.sh
```

### Track B: Interactive Execution

If `data.own` is absent from the workspace path, executing the binary opens a standard interactive checklist to record system accounts, credentials, and custom connection paths:

```bash
bash piseed.sh
```

---

## Deployment Procedures

The script flushes **three** core system configuration profiles into your directory workspace:

- `user-data`
- `meta-data`
- `network-config`

### Installation Guide:

1. Flash your target system distribution image directly onto your microSD media.
2. Mount the processed drive partition on your working computer system.
3. Locate the primary **FAT32 boot volume directory** (commonly labeled `boot`, `bootfs`, or `boot/firmware`).
4. Move `user-data`, `meta-data`, and `network-config` together into the root path of that partition space. No manual labels or image partition table flags need modification.
5. Eject the storage system safely, connect the target card to your system core, attach hardware wires, and connect power.
6. Wait a few minutes for internal post-boot expansion arrays, package alignments, and configuration updates to execute.
