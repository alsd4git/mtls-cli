# mtls-cli

[![CI](https://github.com/alsd4git/mtls-cli/actions/workflows/tests.yml/badge.svg)](https://github.com/alsd4git/mtls-cli/actions/workflows/tests.yml)
[![Latest release](https://img.shields.io/github/v/release/alsd4git/mtls-cli)](https://github.com/alsd4git/mtls-cli/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

Issue, renew, revoke, package, and share client certificates for mutual TLS.
The toolkit runs a pinned Smallstep CA with Docker Compose and uses the `step`
CLI for certificate operations.

## Security model

This project manages private keys and passwords. Read these points before using
it:

- `./step` contains the CA state and keys. Back it up securely and never commit
  it.
- `issued_passwords.csv` stores PKCS#12 passwords in plaintext by design. The
  scripts restrict it to mode `0600`; anyone who can read it can unlock issued
  bundles.
- generated ZIP files contain the encrypted PKCS#12 bundle and public
  certificates. They are not encrypted themselves.
- the temporary HTTP server is suitable only for a trusted local network.
- certificate revocation takes effect only when the relying service checks CRL
  or OCSP status.

## Requirements

- Docker with Compose
- Bash on Linux or macOS
- `step`, OpenSSL, `zip`, and `unzip`
- optional: `qrencode` for terminal QR codes

`./init_cli.sh` installs the command-line dependencies on Debian-based Linux
systems. On macOS, install them with Homebrew:

```bash
brew install smallstep zip
```

The scripts use atomic directory locks supported by both Linux and macOS.
Windows is not a supported execution target.

## Start the certificate authority

```bash
git clone https://github.com/alsd4git/mtls-cli.git
cd mtls-cli
cp .env.example .env
```

Set a strong `STEP_CA_PASSWORD` in `.env`, then start the CA:

```bash
docker compose up -d
```

The default bind address is `127.0.0.1:9001`. Set
`STEP_CA_BIND_ADDRESS=0.0.0.0` only when another host must reach the CA and a
firewall protects the port.

## Issue a client certificate

```bash
./issue-client-cert.sh
```

For non-interactive use, pass the client name:

```bash
./issue-client-cert.sh alice
```

The script restricts client names to a path-safe character set and creates:

```text
certs_output/alice/
  alice.crt
  alice.key
  alice.p12
  alice-certs.zip
issued_passwords.csv
roots.pem
```

The raw private key remains local and is excluded from the ZIP by default. Set
`INCLUDE_RAW_KEY_IN_ZIP=true` only when a recipient requires it.

For a non-loopback `CA_URL`, set `CA_FINGERPRINT`. This pins the CA root during
bootstrap. Omitting the fingerprint is accepted only for the legacy loopback
setup and produces a warning.

## Manage certificates

List the local inventory:

```bash
./cert-manager.sh inventory
```

Renew a certificate and rebuild its bundle with the recorded password:

```bash
./cert-manager.sh renew alice
```

Revoke a certificate:

```bash
./cert-manager.sh revoke alice "device lost"
```

Renewal keeps timestamped backups of the previous certificate and restores them
if the operation fails.

## Share one bundle

```bash
./serve-certs.sh certs_output/alice/alice-certs.zip
```

The command serves only the selected file, prints a QR code when `qrencode` is
available, and stops after five minutes. Configure the lifetime with
`EXPIRE_MINUTES`, the port with `PORT`, and address detection with `SHARE_IP`.

On Android, extract the ZIP, open the `.p12` file, and enter the password from
`issued_passwords.csv`. Android places the certificate under its credential
storage settings.

## Configuration

The main overrides are `CA_URL`, `CA_FINGERPRINT`, `PROVISIONER`,
`CERT_DURATION`, `OUT_DIR`, `ROOT_CA`, and `PASSWORD_LOG`. See the scripts and
`.env.example` for their defaults.

## Validation

```bash
shellcheck ./*.sh ./lib/*.sh ./tests/*.sh
./tests/run.sh
STEP_CA_PASSWORD=test-only docker compose config --quiet
```

The tests use a fake `step` command and temporary OpenSSL certificates. They do
not contact a live CA.

## Documentation and releases

- [Certificate format recap](cert-recap.md)
- [Nginx Proxy Manager guide](docs/nginx-proxy-manager.md)
- [Changelog](CHANGELOG.md)
- [GitHub releases](https://github.com/alsd4git/mtls-cli/releases)

## License

MIT. See [LICENSE](LICENSE).
