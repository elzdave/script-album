# Ngrok Linux Service installer/uninstaller

## Installation :

1. Copy this directory to the target machine (eg: Raspberry Pi, your Linux workstation, etc).
2. Login to [Ngrok Dashboard](https://dashboard.ngrok.com/), then copy your `authtoken` from [default authtoken](https://dashboard.ngrok.com/get-started/your-authtoken) page or you can create custom `authtoken` from the [tunnel authtoken](https://dashboard.ngrok.com/tunnels/authtokens) page.
3. Inspect and modify the example configuration file `ngrok.yml.example`, by default this config will serve both **HTTP** at port 80 (default HTTP port) and **TCP** at port 22 (for SSH connection). Do **not** modify anything in <> tag (eg : <web_domain>)
4. Run `sudo bash nls.sh`, enter number 1 for installation and complete the required input.
5. You're good to go!

## Uninstallation :

1. Run `sudo bash nls.sh`, enter number 2 and wait until it finished.

## Operating System Support :

Any Linux-based operating system running on any CPU.
