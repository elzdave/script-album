# Fearless : Fedora Server on Raspberry Pi Headless patch

- This script require **administrative privilege**

A simple post-flash script to configure:

1. WiFi
2. Username and password
3. Resize SD card space to use all available free space
4. Disable initial Fedora setup
5. SSH key creation and add current host user's public key to 'authorized_keys'

### Usage :

1. Flash the raw Fedora image to Raspberry Pi SD card using [balenaEtcher](https://etcher.balena.io/) or any flasher.
2. Unplug and replug the SD card on the current working host.
3. Run the following script

   ```bash
   chmod 750 fearless
   sudo bash fearless /path/to/sdcard/disk
   ```

   Example :

   ```bash
   chmod 750 fearless
   sudo bash fearless /dev/sdb
   ```

   You can use `sudo lsblk` to find the right SD card **disk** (not partition) absolute path.

### Notes :

If you get some error like

```bash
mount: /mnt/fdroot: can't read superblock on /dev/mapper/fedora-root.
       dmesg(1) may have more information after failed mount system call.
```

which usually lead to

```bash
xfs_growfs: /mnt/fdroot is not a mounted XFS filesystem
...
chroot: failed to run command ‘/bin/bash’: No such file or directory
...
umount: /mnt/fdroot: not mounted.
```

Just try to re-run this script, or try to unplug and replug the SD card again then re-run this script.

## Fedora Version Support

A raw (\*.xz) image of Fedora Server from version 34 or newer.
