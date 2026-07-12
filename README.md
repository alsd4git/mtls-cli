# 🔐 mtls-cli

A simple toolkit to generate, package, and securely share long-lived **client certificates** for **mutual TLS (mTLS)** authentication — perfect for self-hosted services, homelabs, friends, family, or small teams.

Built on top of [Smallstep CA](https://smallstep.com/docs/step-ca) and optimized for:
- Easy usage via CLI
- Secure `.p12` bundling
- QR-based sharing over local network
- Manual or semi-automated client install

---

## 🧰 What's Included

| Script/File                        | Description                                                              |
|-----------------------------------|--------------------------------------------------------------------------|
| `compose.yml`                     | Pinned, local-only-by-default Docker Compose setup for Step CA           |
| `init_cli.sh`                     | Installs Step CLI, `zip`, `flock`, and `qrencode` (optional)             |
| `issue-client-cert.sh`           | Generates 1-year client cert, `.p12`, zipped bundle, logs it             |
| `cert-manager.sh`                | Inventory, renewal, and revocation commands                              |
| `serve-certs.sh`                 | Serves one bundle via temporary HTTP + QR code                            |
| `cert-recap.md`                  | Cheat sheet explaining `.crt`, `.p12`, `.key`, etc.                      |
| `.gitignore`                     | Ignores secrets, output, and certs                                       |
| `docs/nginx-proxy-manager.md`    | Extra guide to use mTLS with Nginx Proxy Manager (NPM)                   |
| `roots.pem` *(generated)*        | Cached copy of the root certificate (created on first run)              |
| `issued_passwords.csv` *(generated)* | Logs all issued certs and passwords (created by the script)           |

---

### 💡 Note:
- Files marked with *(generated)* are **not included in the repo** by default.
- They are automatically created when using the scripts.

---

## 🚀 Getting Started

### 0. Start your Step CA with Docker

```bash
cp .env.example .env
# Edit .env and replace STEP_CA_PASSWORD first.
docker compose up -d
```

The version-pinned CA is available at `https://localhost:9001`. It binds to
`127.0.0.1` by default, uses `no-new-privileges`, has an init process, and a
graceful stop policy. Set `STEP_CA_BIND_ADDRESS=0.0.0.0` only when other LAN
hosts must reach the CA, and protect that port with a firewall.

The `./step` state directory and `.env` are ignored by Git. Back up the `step`
directory securely: losing its keys means losing the CA.

---

### 1. Install CLI tools (optional)

```bash
chmod +x init_cli.sh
./init_cli.sh
```

This installs:
- `step` (CLI for Step CA)
- `zip` (for packaging certs)
- `flock` from `util-linux` (for safe lifecycle and password-ledger locking)
- `qrencode` (optional for sharing)

---

### 2. Issue a certificate:

```bash
chmod +x issue-client-cert.sh
./issue-client-cert.sh
# Or non-interactively provide only the client name:
./issue-client-cert.sh alice
```

- Prompts for a username (e.g. `alice`)
- Issues a 1-year client certificate
- Bundles it into a `.p12` with a secure password
- Zips the P12 and public certificates into a ready-to-share `.zip`
- Logs the password and timestamp to `issued_passwords.csv`
- Optionally serves only that bundle over temporary HTTP with a QR code

Client names are restricted to a path-safe character set. Configuration can be
overridden with `CA_URL`, `PROVISIONER`, `CERT_DURATION`, `OUT_DIR`, `ROOT_CA`,
and `PASSWORD_LOG`. For a non-loopback `CA_URL`, you must set `CA_FINGERPRINT`
to bootstrap `roots.pem` with explicit fingerprint verification. For a loopback
CA only, omitting it produces a warning and uses the legacy local
`curl --insecure` bootstrap.

---

## 📂 Output Structure

Each issued cert creates:
```
certs_output/
  └── alice/
      ├── alice.crt       # Public certificate
      ├── alice.key       # Private key
      ├── alice.p12       # Password-protected bundle
      └── alice-certs.zip # P12, public cert, and root CA; ready to share
issued_passwords.csv       # Log of all issued certs and passwords
roots.pem                  # Cached CA root
```

`issued_passwords.csv` intentionally keeps plaintext passwords because this is
part of this toolkit's operating workflow. The scripts preserve this behavior,
set the file to mode `0600`, and append `issued`/`renewed` audit records. Protect
and back up this file as sensitive data.

The raw private key remains available locally but is no longer placed in the ZIP
by default. The ZIP itself is also unencrypted by default: it contains only the
encrypted P12 and public certificates, while avoiding weak ZipCrypto and a
password visible in the process list. Set `LEGACY_ZIP_PASSWORD=true` only for a
legacy recipient that requires the previous ZIP password behavior, and
`INCLUDE_RAW_KEY_IN_ZIP=true` only when the raw key is explicitly required.

## 🔄 Certificate lifecycle

List locally managed certificates, serials, expiration dates, and status:

```bash
./cert-manager.sh inventory
```

Renew a client certificate and rebuild its P12/ZIP with the latest recorded
plaintext password:

```bash
./cert-manager.sh renew alice
```

The old certificate is retained as a timestamped `*.before-renew.*` backup. If
renewal fails, it is restored automatically.

Revoke a certificate using its own certificate/key pair:

```bash
./cert-manager.sh revoke alice "device lost"
```

Revocation prevents future renewal. Immediate rejection additionally requires
the relying service to check a CRL or OCSP; simply configuring the root CA in a
reverse proxy does not make active revocation automatic.

---

## 📱 How to Install on Android

1. Receive the `.zip` file
2. Unzip and tap the `.p12`
3. Enter the password (shown after creation or found in `issued_passwords.csv`)
4. Installed cert will appear under `Settings → Security → Encryption & credentials`

---

## 🌐 Share via QR/HTTP

Want to quickly transfer certs to another device?

```bash
./serve-certs.sh
# Or select a bundle explicitly:
./serve-certs.sh certs_output/alice/alice-certs.zip
```

This will:
- Serve only the selected ZIP (or the newest bundle when omitted)
- Show a QR code to scan from another device on your LAN
- Auto-stop the server after 5 minutes
- Kill the HTTP process and verify removal of its temporary directory on exit,
  expiry, Ctrl+C, or failure

Override the lifetime with `EXPIRE_MINUTES`, the port with `PORT`, or IP
detection with `SHARE_IP`. HTTP is intentionally suitable only for a trusted
local network: the P12 remains password-protected, but the ZIP and raw transport
are not encrypted.

## 🧪 Validation

The test suite uses a fake `step` command plus temporary, real OpenSSL
certificates. It exercises validation, plaintext password reuse, inventory,
renewal/repackaging, revocation arguments, single-file sharing, and cleanup:

```bash
./tests/run.sh
STEP_CA_PASSWORD=test-only docker compose config --quiet
```

---

## 🧠 Extras

- `cert-recap.md` explains all the formats: `.crt`, `.key`, `.p12`, `.pem`, etc.
- [docs/nginx-proxy-manager.md](docs/nginx-proxy-manager.md) contains
  Nginx Proxy Manager-specific setup for mTLS

---

## 💬 Feedback

Got ideas or want to contribute? Open an issue or ping me!

## License

MIT. See [LICENSE](LICENSE).
