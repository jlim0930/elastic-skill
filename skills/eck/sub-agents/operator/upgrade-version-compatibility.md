---
name: eck-upgrade-version-compatibility
description: Diagnose upgrade failures and version mismatches.
---
# ECK Upgrade & Version Compatibility

**Purpose:** Diagnose upgrade failures and version mismatches.

**Use When:**
- Operator upgrade stuck
- Stack version upgrade failed
- CRD mismatch

**Do Not Use When:**
- Initial deployment failures not related to version

**Inputs Needed:**
- Current versions
- Target versions
- Upgrade logs

**Steps:**
1. Check version compatibility matrix (refer to `../../../../shared/version_compatibility_checks.md`).
2. Check operator deployment status during upgrade.
3. Monitor rolling upgrade progress of StatefulSets.
4. Confirm no breaking changes in manifest schema.

**Output:**
- Identify upgrade blockers and recommended resolution.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
