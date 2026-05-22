---
name: eck
description: Routes to specific ECK sub-agents for troubleshooting Elastic Cloud on Kubernetes.
---
# ECK — Orchestrator

**Purpose:** Route ECK issues to specific sub-agents.

**Use When:**
- Troubleshooting Elastic Stack workloads on Kubernetes (ECK).
- Operator reconciliation, pod scheduling, network, or storage issues.

**Do Not Use When:**
- Troubleshooting ECH (Elastic Cloud Hosted) or ECE (Elastic Cloud Enterprise).
- Troubleshooting standalone un-orchestrated Elasticsearch.

**Inputs Needed:**
- Symptom description.
- Component involved.

**Steps:**
1. Identify product/component.
2. Identify issue domain.
3. Route narrow to the most specific sub-agent.
4. Reference shared skills when applicable (e.g., `../../shared/log_filtering.md`).

## Sub-Agent Roster

### Operator Control Plane
- `operator/health-reconciliation.md` — Operator health, reconciliation errors.
- `operator/custom-resource-config.md` — Manifest validation, resource associations.
- `operator/upgrade-version-compatibility.md` — Operator and stack upgrades.
- `operator/licensing.md` — License management.

### Elastic Workloads
- `workloads/elasticsearch.md` — ES cluster health, shards, config on ECK.
- `workloads/kibana.md` — Kibana startup, migrations.
- `workloads/agent-fleet.md` — Elastic Agent and Fleet management.
- `workloads/apm.md` — APM Server health.
- `workloads/machine-learning.md` — ML node scheduling.
- `workloads/snapshot-repository.md` — Backup and restore operations.
- `workloads/autoscaling.md` — ECK autoscaling.

### Kubernetes Infrastructure
- `infrastructure/networking-service-discovery.md` — DNS, Service, NetworkPolicy.
- `infrastructure/tls-certificates.md` — Certificate trust, custom CA.
- `infrastructure/storage-pvc-statefulset.md` — PVC binding, storage classes.
- `infrastructure/scheduling-nodes-resources.md` — Pod scheduling, resources.
- `infrastructure/security-rbac-pod.md` — RBAC, Pod Security Admission.
- `infrastructure/ingress-exposure.md` — Ingress, LoadBalancers.

### Operations
- `operations/performance-capacity.md` — CPU/Memory/IO performance.
- `operations/observability-diagnostics.md` — Log analysis, events.

**Output:**
- Route to sub-agent.

**Sources:**
- KCS / Docs / Web (via `retrieval-protocol.md`)
