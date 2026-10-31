# Security policy

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/alsd4git/mtls-cli/security/advisories/new).
Do not disclose exploit details or sensitive data in public issues or pull requests.

Include the affected commit or version, expected impact and minimal reproduction
steps. Use synthetic examples and redact screenshots and logs. If your own
credential was exposed, revoke or rotate it. Report credentials you do not control
promptly and privately; do not use or attempt to revoke them.

## Versions and maintenance

Check the current default branch, `main`, and, if using a release,
the latest release published by this repository before reporting an issue.
Fixes, when provided, target the default branch. Older versions do not receive
separate backports. Reports are handled on a best-effort basis without guaranteed
response or remediation times.

## Safe reproduction

Use temporary stores, test CAs and disposable certificates. Never include production private keys, passphrases or real certificate packages. Do not issue or revoke production certificates to demonstrate an issue.
