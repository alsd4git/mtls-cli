# 🔐 Homelab mTLS Certificate Issuer

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
| `compose.yml`                     | Docker Compose setup for Step CA                                         |
| `init_cli.sh`                     | Installs Step CLI, `zip`, and `qrencode` (optional)                      |
| `issue-client-cert.sh`           | Generates 1-year client cert, `.p12`, zipped bundle, logs it             |
| `serve-certs.sh`                 | Serves the certs via local HTTP + QR code (auto-expires)                 |
| `cert-recap.md`                  | Cheat sheet explaining `.crt`, `.p12`, `.key`, etc.                      |
| `.gitignore`                     | Ignores secrets, output, and certs                                       |
| `README_NPM.md`                  | Extra guide to use mTLS with Nginx Proxy Manager (NPM)                   |
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
docker compose up -d
```

Your CA will now be available at `https://localhost:9001`

---

### 1. Install CLI tools (optional)

```bash
chmod +x init_cli.sh
./init_cli.sh
```

This installs:
- `step` (CLI for Step CA)
- `zip` (for packaging certs)
- `qrencode` (optional for sharing)

---

### 2. Issue a certificate:

```bash
chmod +x issue-client-cert.sh
./issue-client-cert.sh
```

- Prompts for a username (e.g. `alice`)
- Issues a 1-year client certificate
- Bundles it into a `.p12` with a secure password
- Zips all files into a ready-to-share `.zip`
- Logs the password and timestamp to `issued_passwords.csv`
- Optionally serves the bundle over HTTP with QR code

---

## 📂 Output Structure

Each issued cert creates:
```
certs_output/
  └── alice/
      ├── alice.crt       # Public certificate
      ├── alice.key       # Private key
      ├── alice.p12       # Password-protected bundle
      └── alice-certs.zip # Ready to share
issued_passwords.csv       # Log of all issued certs and passwords
roots.pem                  # Cached CA root
```

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
```

This will:
- Serve the `certs_output/` folder via HTTP
- Show a QR code to scan from another device on your LAN
- Auto-stop the server after 5 minutes

---

## 🧠 Extras

- `cert-recap.md` explains all the formats: `.crt`, `.key`, `.p12`, `.pem`, etc.
- `README_NPM.md` contains Nginx Proxy Manager-specific setup for mTLS

---

## 💬 Feedback

Got ideas or want to contribute? Open an issue or ping me!
