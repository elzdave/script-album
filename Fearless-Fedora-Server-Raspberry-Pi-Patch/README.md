# Fearless : Fedora Server on Raspberry Pi Headless patch

- This script require **administrative privilege**

A simple post-flash script to configure:

1. WiFi
2. Username and password
3. Resize SD card space to use all available free space
4. Disable initial Fedora setup
5. SSH key creation

Usage :

1. Flash the raw Fedora image to Raspberry Pi SD card using [balenaEtcher](https://etcher.balena.io/) or any flasher.
2. Unplug and replug the SD card from current PC.
3. Run the following script

   ```bash
   chmod 750 fearless
   bash fearless /path/to/sdcard/disk
   ```

   No need to use `sudo` in main file execution, because some of the things inside require regular user privilege.

   Example :

   ```bash
   chmod 750 fearless
   bash fearless /dev/sdb
   ```

   You can use `sudo lsblk` to find the right SD card **disk** (not partition) absolute path.

## Fedora Version Support

A raw (\*.xz) image of Fedora Server from version 34 or newer.
