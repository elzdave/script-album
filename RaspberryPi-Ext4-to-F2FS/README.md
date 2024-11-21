# RaspberryPi Ext4 to F2FS

This script will:

1. Decompress the live image
2. Backup its root contents to temporary F2FS partition
3. Patch `/etc/fstab` and `cmdline.txt` entry to enable booting from F2FS partition
4. Restore the root contents data
5. Re-compress patched image

## Requirements

1. 10GB free disk space
2. 4GB or more RAM
3. Dual core or more processor

## Usage :

1. Run `sudo bash rpif2fs.sh "/path/to/compress/live/image.{raw/img}.xz"`, where `/path/to/compress/live/image.{raw/img}.xz` is the path to the corresponding live image to be used. Please note the double tick ("") is used to allow using path containing spaces.
2. Follow the instruction on the screen.

## Tested Live Image :

- Official Raspberry Pi OS
- AlmaLinux image for Raspberry Pi
- Rocky Linux image for Raspberry Pi

## Supported Operating System :

APT or DNF based Linux operating system running on any CPU (Fedora, AlmaLinux, Rocky Linux, Debian, Ubuntu, etc).
