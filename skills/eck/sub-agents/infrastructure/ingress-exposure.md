---
name: eck-ingress-exposure
description: Diagnose external access, Ingress, and LoadBalancer issues.
---
# ECK Ingress & Exposure

**Purpose:** Diagnose external access, Ingress, and LoadBalancer issues.

**Use When:**
- Cannot access externally
- Ingress routing fails
- LB health check fails

**Do Not Use When:**
- Internal pod-to-pod connectivity issues

**Inputs Needed:**
- Ingress config
- Service type
- Health check status

**Steps:**
1. Inspect Ingress resource for correct backend routing and TLS termination.
2. Check Service type and external IP allocation.
3. Verify load balancer can reach pod health check endpoints.

**Output:**
- Identify external exposure misconfiguration and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
