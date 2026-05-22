---
name: eck-tls-certificates
description: Diagnose certificate trust, SAN, and expiration issues on ECK.
---
# ECK TLS & Certificates

**Purpose:** Diagnose certificate trust, SAN, and expiration issues on ECK.

**Use When:**
- Certificate trust fails
- SAN mismatch
- Expired certificates

**Do Not Use When:**
- Network connectivity without TLS errors

**Inputs Needed:**
- Certificate secrets
- TLS error messages

**Steps:**
1. Inspect ECK managed certificates for validity and expiration (refer to `../../../../shared/tls_certificate_checks.md`).
2. Verify custom certificate secrets are correctly formatted and referenced.
3. Compare certificate SANs with accessed service names.

**Output:**
- Identify certificate configuration error and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
