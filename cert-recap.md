# Here’s a handy **comparison table** that breaks down the most common certificate formats: `.crt`, `.key`, `.pem`, `.p12`, and others like `.cer`, `.der`, `.pfx`, etc

---

## 📦 Certificate Format Cheat Sheet

| Format | File Extension(s) | Contains                          | Encoded As      | Encrypted? | Use Case |
|--------|-------------------|------------------------------------|------------------|------------|----------|
| **CRT**  | `.crt`, `.cer`     | Public certificate only            | Usually **PEM**  | ❌ No       | Web servers, clients, trust chains |
| **KEY**  | `.key`             | Private key only                   | **PEM**          | ❌ / ✅     | Paired with certs, server/client auth |
| **PEM**  | `.pem`             | Can contain cert, key, or both     | **PEM (Base64)** | ❌ / ✅     | Flexible format (OpenSSL default) |
| **P12**  | `.p12`, `.pfx`     | Cert + private key + CA chain      | **Binary**       | ✅ Yes     | Used on Android, Windows, macOS, etc. |
| **PFX**  | `.pfx`             | Same as `.p12`                     | **Binary**       | ✅ Yes     | Windows legacy (same format as `.p12`) |
| **DER**  | `.der`, `.cer`     | Single cert (binary version of CRT)| **Binary**       | ❌ No       | Java-based apps (Tomcat, etc.) |
| **CSR**  | `.csr`             | Certificate Signing Request        | **PEM**          | ❌ No       | Sent to CA to get a signed cert |
| **JKS**  | `.jks`             | Java KeyStore (multiple entries)   | **Binary**       | ✅ Yes     | Java apps like Tomcat/Jetty |
| **PKCS#8** | `.key`, `.pem`   | Private key (newer format)         | PEM / DER        | ✅ or ❌    | Often used in modern systems |
| **PKCS#7** | `.p7b`, `.p7c`   | Cert chain (no private key)        | **Binary/PEM**   | ❌ No       | Used for bundling CA chains |

---

## 🔍 What Are We Using in Our Setup

| File        | Contains             | Format     | Use In Your Flow                   |
|-------------|----------------------|------------|------------------------------------|
| `*.crt`     | Public cert          | PEM (`CRT`) | Shared with NPM or clients         |
| `*.key`     | Private key          | PEM        | Needed for `.p12` or server usage  |
| `*.p12`     | Cert + key + CA chain| Binary     | 📱 For Android, iOS, etc.          |
| `root_ca.crt` | Root certificate   | PEM (`CRT`) | Used by NPM for mTLS trust         |

---

### 💡 Notes

- `.pem`, `.crt`, `.cer`, `.key` are often interchangeable **as long as content matches**
- `.p12`/`.pfx` is the best format to **bundle everything securely**
- Use `openssl` to convert between all of these
