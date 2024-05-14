# Nginx Patched Installation Script for Aapanel

The purpose of this script is to enable Nginx version 1.22 onwards installation by changing the dependent OpenSSL version from 1.1.1q to 3.2.x, because OpenSSL v1.1.1q has known bug that preventing it from being successfully compiled and used as dependency of Nginx source code. If you fail to compile Nginx in Aapanel App Store, you can directly use this script to install Nginx alá Aapanel and your desired Nginx version will be available on Aapanel 👻

This folder contains 2 scripts that serve different purposes:

- `nginx.v2.sh` : Nginx installer script, require **administrative privilege**

  Usage :

  ```bash
  sudo bash nginx.v2.sh [mode] [version]
  ```

  Example :

  ```bash
  sudo bash nginx.v2.sh install 1.25
  ```

  The valid options for [mode] are `install`, `uninstall`, and `update`.

  The valid tested [version] are:

  - All version: `1.8`, `1.10`, `1.12`, `1.14`, `1.15`, `1.16`, `1.18`, `1.18.gmssl`, `1.19`, `1.20`, `1.21`, `1.22`, `1.23`, `1.24`, `1.25`, `1.26`, `openresty`, `tengine`.
  - Tested: `1.22`, `1.23`, `1.24`, `1.25`, `1.26`, `openresty`, `tengine`.

- `runtest.sh` : Nginx script tester, require **administrative privilege** and `nginx.v2.sh`.

  Usage :

  ```bash
  sudo bash runtest.sh
  ```

  The runtest.sh is essentially a script to test `nginx.v2.sh` execution [mode] and different Nginx [version] by install-uninstall them sequentially, and performing update from defined oldest version to the defined latest version. This script will produces several log files in it's current working directory.

## CPU Architecture Support

- x86-64 (amd64)
- ARM64 (aarch64)

## Operating System Support

- All operating systems supported by Aapanel
- Fedora 39+
