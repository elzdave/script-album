# SSH Key(s) directory.

Put your pre-generated public and private SSH key(s) here. If you want to generate them, run command below at current directory:

- Ed25519 key type: `ssh-keygen -t ed25519 -f ./id_ed25519 -C "YourHostname"`
- ECDSA key type: `ssh-keygen -t ecdsa -b 521 -f ./id_ecdsa -C "YourHostname"`
- RSA key type: `ssh-keygen -t rsa -b 4096 -f ./id_rsa -C "YourHostname"`

Change `"YourHostname"` to your desired hostname or anything unique to identify the key.

## Which key type suits my machine?

- RSA are the oldest and supported by virtually all servers or SSH clients, but pay attention to generate long keys for better security (> 2048 bit). Use this type if you want to connect to old legacy SSH server/client.
- ECDSA are supported by most servers and has shorter keys with same or better security than RSA.
- Ed25519 are the newest algorithm and not all SSH clients has supported it yet. It has even shorter keys with very good security compared to ECDSA and RSA. Use this if you want the very short keys with very good security, and don't want to connect to legacy SSH server/client.
- If you still can't decide, generate all types to maximize compatibility.
