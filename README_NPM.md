# 🔐 Using Client Certificates with Nginx Proxy Manager (NPM)

This guide shows how to configure **Nginx Proxy Manager** (NPM) to use **mutual TLS (mTLS)** authentication with client certificates generated using the `issue-client-cert.sh` script.

> 📌 mTLS ensures that only users with valid certificates can access specific services — ideal for securing admin panels, dashboards, or private endpoints.

---

## ✅ Prerequisites

- You’ve already issued a client certificate using the main script.
- You have access to your root CA certificate: `roots.pem` (generated or cached).
- NPM is running via Docker and you can edit its config/volumes.

---

## ⚙️ Step 1: Copy Root CA into NPM Container

Mount your `roots.pem` (or `root_ca.crt`) into the NPM container:

### Example Docker volume:
```yaml
services:
  npm:
    image: jc21/nginx-proxy-manager
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
      - /home/youruser/step-ca/roots.pem:/etc/nginx/ssl/roots.pem:ro
```

Or copy manually:
```bash
docker cp roots.pem npm:/etc/nginx/ssl/roots.pem
```

---

## 🛡️ Step 2: Enable mTLS for a Proxy Host

1. Open NPM UI → Proxy Hosts → Edit the host you want to protect.
2. Go to the **Advanced** tab.
3. Add the following block:

```nginx
ssl_client_certificate /etc/nginx/ssl/roots.pem;
ssl_verify_client on;
```

✅ This tells Nginx to:
- Require a client certificate
- Verify it against your CA's root

---

## 🔄 Step 3: Restart NPM

You must restart NPM for changes to take effect:
```bash
docker restart npm
```

---

## 🔐 Accessing the Protected Service

From the client device:
- Install the `.p12` bundle you created
- Use a browser that supports client certs (most do)
- Visit the domain/subdomain — NPM will prompt for a client certificate

If the cert is valid and signed by your CA, access is granted 🎉

---

## 🧪 Troubleshooting

| Problem | Cause | Solution |
|--------|-------|----------|
| 400 Bad Request | No certificate presented | Check browser or mobile config |
| 403 Forbidden | Invalid or unknown cert | Ensure it's signed by your CA |
| NPM won’t start | Bad config in Advanced tab | Remove `ssl_` lines and retry |

---

## ✅ Recommended Use Cases

- Protecting admin panels (NPM, Portainer, etc.)
- Exposing private services to a trusted circle
- Securing public domains with client-side identity checks

---

## 📦 Related Files

- `roots.pem` → trusted CA file in NPM
- `*.p12` → installed on client devices
- `issue-client-cert.sh` → generates everything you need

---

## 🛡️ Pro Tips

- Use mTLS together with Authelia for SSO + 2FA + identity-based policies.
- Rotate client certs yearly using the script — it's fast.
- Use `qrencode` and `serve-certs.sh` to quickly deliver certs to phones.
