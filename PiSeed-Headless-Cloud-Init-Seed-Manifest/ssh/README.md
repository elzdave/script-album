# SSH Keys Directory

Place your pre-generated public and private SSH keys in this directory. If you need to generate new keys, execute the appropriate command for your preferred algorithm from within this directory:

### Ed25519 Key Type

```bash
ssh-keygen -t ed25519 -f ./id_ed25519 -C "YourHostname"
```

### ECDSA Key Type

```bash
ssh-keygen -t ecdsa -b 521 -f ./id_ecdsa -C "YourHostname"
```

### RSA Key Type

```bash
ssh-keygen -t rsa -b 4096 -f ./id_rsa -C "YourHostname"
```

> **Note:** Replace `"YourHostname"` with your actual hostname, email, or a unique comment string to easily identify the key.

---

## Choosing the Right Key Type

- **RSA:** The most widely compatible and legacy-friendly algorithm, supported by virtually all SSH servers and clients. For modern security compliance, always ensure you generate a key length of at least **4096 bits**. Use this type if you need to interface with older, legacy infrastructure.
- **ECDSA:** Supported by most modern systems. It offers significantly shorter key lengths while providing equivalent or superior security compared to traditional RSA keys.
- **Ed25519:** The most modern and highly recommended public-key algorithm. It boasts the shortest key lengths, exceptional cryptographic strength, and high performance. Note that it may not be supported by legacy SSH clients or outdated server software. Use this as your default choice for modern environments.
- **Fallback Strategy:** If you are unsure about the capabilities of your target infrastructure, you can generate all available key types to maximize cross-platform compatibility.
