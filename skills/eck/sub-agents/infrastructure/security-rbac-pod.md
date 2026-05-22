---
name: eck-security-rbac-pod
description: Diagnose RBAC, ServiceAccounts, and Pod Security issues.
---
# ECK Security & RBAC

**Purpose:** Diagnose RBAC, ServiceAccounts, and Pod Security issues.

**Use When:**
- Operator lacks permissions
- Pod Security Admission fails
- SCC issues

**Do Not Use When:**
- Elasticsearch user authentication (use workloads)

**Inputs Needed:**
- RBAC roles
- Namespace labels
- Security context

**Steps:**
1. Check operator ServiceAccount permissions (refer to `../../../../shared/authentication_checks.md`).
2. Verify Pod Security Admission (PSA) labels on namespace.
3. Confirm Security Context Constraints (SCC) on OpenShift.

**Output:**
- Identify permission or security context block and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
