---
name: eck-licensing
description: Diagnose enterprise license and feature enablement issues.
---
# ECK Licensing

**Purpose:** Diagnose enterprise license and feature enablement issues.

**Use When:**
- Enterprise features disabled
- License secret not recognized
- Trial expired

**Do Not Use When:**
- Standard open-source feature issues

**Inputs Needed:**
- License secret name
- Elasticsearch license status

**Steps:**
1. Check license status in Elasticsearch.
2. Verify license secret exists and is correctly formatted.
3. Check operator logs for license validation errors (refer to `../../../../shared/log_filtering.md`).

**Output:**
- Actionable steps to apply or fix the license.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
