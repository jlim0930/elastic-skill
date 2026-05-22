---
name: eck-networking-service-discovery
description: Diagnose DNS, service, and pod connectivity issues on ECK.
---
# ECK Networking & Service Discovery

**Purpose:** Diagnose DNS, service, and pod connectivity issues on ECK.

**Use When:**
- Service DNS fails
- Pod-to-pod communication fails
- NetworkPolicy blocks traffic

**Do Not Use When:**
- Ingress/LoadBalancer external exposure issues

**Inputs Needed:**
- Service definitions
- NetworkPolicies
- Connectivity test results

**Steps:**
1. Check service endpoints and readiness.
2. Test DNS resolution from within pods.
3. Test transport layer connectivity between pods (refer to `../../../../shared/network_connectivity_checks.md`).
4. Audit NetworkPolicies for blocked traffic.

**Output:**
- Identify network blockage or DNS issue and recommended fix.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
