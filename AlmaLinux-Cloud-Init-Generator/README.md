# AlmaLinux Cloud Init Generator

This AlmaLinux Cloud Init generator will build an `user-data` configuration file to be used by AlmaLinux instances for system initialization at the first time boot. Specially tuned for Raspberry Pi images.

What this script do:

1. Create user account
2. Configure timezone, hostname
3. Enable/disable SSH password login
4. Change SSH port
5. Setup WiFi connection
6. Tune the SELinux permission for SSH
7. Enable/disable system reboot after initialization

## Usage :

1. [Optional] put pre-generated SSH key(s) on folder `ssh`.
2. Run `bash almacigen.sh` and follow the instruction.
3. Copy the generated `user-data` file to the designated partition used for booting on the fresh installation of AlmaLinux's drive, eg: `CIDATA` partition.
4. Boot the AlmaLinux instance.

## Operating System Support :

APT or DNF based Linux operating system running on any CPU (Fedora, AlmaLinux, Rocky Linux, Debian, Ubuntu, etc).
