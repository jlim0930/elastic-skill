---
name: ece-known-issues-restrictions
description: Diagnoses ECE issues caused by documented known problems or platform restrictions including documented ECE known issues, unsupported virtualization behavior, version-specific platform bugs, hosted feature expectations incorrectly applied to ECE, and operational limitations due to architecture or role placement.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECE — Known Issues & Platform Restrictions Sub-Agent

Scope: Documented ECE known issues, unsupported virtualization behaviors, version-specific platform bugs, hosted feature expectations applied incorrectly to ECE, operational limitations due to architecture/role placement.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECE known issue"`, `"ECE unsupported behavior"`, `"ECE version bug"`, `"ECE architecture limitation"`, `"ECE VMotion"`, `"ECE virtualization restriction"`.

## Diagnostic Steps

### 1. Version Inventory
Always capture the ECE version first for known issue lookup:
```bash
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/platform" | jq '{ece_version:.version}'

# Stack versions of managed deployments
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/clusters/elasticsearch" | \
  jq '[.elasticsearch_clusters[] | {name:.cluster_name, stack_version:.elasticsearch.version}] | group_by(.stack_version) | map({version:.[0].stack_version, count:length})'
```

### 2. Common ECE Known Issues

| Symptom | Known cause | Fix/workaround |
|---|---|---|
| Proxy cert invalid after endpoint URL change | Cert SANs don't cover new domain | Rotate proxy cert (see `tls-certificates.md`) |
| 398-day cert rejected by browsers | Cert validity > 398 days | Rotate certificate |
| ZK session expiry after VMotion | VMotion pauses the VM during ZK heartbeat | Disable VMotion for ECE hosts |
| Docker iptables rules flushed by firewalld | `firewalld --reload` removes Docker NAT rules | `systemctl restart docker` after firewall reload |
| SELinux blocks container file access | Missing SELinux context on `/mnt/data/elastic` | Apply SELinux policy or run install with `--selinux` |
| Allocator disconnected after network change | IP address of allocator changed | Update runner config with new IP |
| Admin console shows wrong metrics | Logging-and-metrics cluster lagging or stale | Restart logging cluster; check beats runner |
| Plan change stuck after ZK leadership change | ZK leader election in progress during plan | Wait for election to complete; retry plan |

### 3. Unsupported Virtualization Behaviors
**VMotion (VMware)**: Not supported. ZooKeeper's heartbeat/session timeout model is incompatible with VM migration pauses.

**Memory ballooning**: Not supported. VMs hosting ECE allocators must have memory reserved (no balloon driver active) or Elasticsearch containers will OOM due to unexpected memory contention.

**Overcommitted storage (thin provisioning)**: Supported with caution. Thin-provisioned storage that runs out causes container write failures and data corruption. Always maintain 20%+ free space.

### 4. ECE vs. ECH Feature Expectations
ECE is self-managed — some ECH (Elastic Cloud Hosted) features do not apply:

| ECH behavior | ECE equivalent |
|---|---|
| Automatic snapshotting | Must configure snapshot repository and ECE snapshot settings |
| AutoOps recommendations | No AutoOps in ECE — manual capacity planning required |
| Automatic certificate management | Platform certs must be manually rotated |
| Elastic manages the platform | Customer manages all ECE hosts |
| Traffic filters via console | Must configure network-level firewall or load balancer ACLs |

### 5. Architecture/Role Placement Limitations
| Limitation | Description |
|---|---|
| ZK quorum requires odd number | 3 or 5 coordinator hosts with directors; 2 causes split-brain risk |
| Single coordinator | No HA for platform if only 1 coordinator |
| Proxy is SPOF if 1 proxy host | All deployment traffic goes through the proxy — needs LB with multiple proxies |
| System deployments on limited allocators | If admin-console-ES and security-cluster share the same single allocator, both fail together |
| Allocator disk full stops placement | No new instances can be placed on allocators with < 5% free disk |

### 6. Overlay2 on XFS — Quota Requirement
On XFS-backed storage, Docker overlay2 requires `pquota` mount option:
```bash
# Check if XFS has pquota
mount | grep "/mnt/data" | grep pquota
# Or
cat /etc/fstab | grep "/mnt/data"
```
Missing `pquota` = overlay2 will fail on XFS.

### 7. Docker Version Compatibility
ECE requires a specific range of Docker versions. Very new Docker versions may not be certified:
```bash
docker --version
```
Check the ECE compatibility matrix in the documentation for the certified Docker version range for your ECE version.

### 8. Stack Version Upgrade Restrictions in ECE
ECE supports upgrading stacks within a major version (7.x → 7.y) and across major versions (7.x → 8.x) under specific conditions:
- Cannot skip major versions (7.x cannot go directly to 9.x)
- ECE version must support the target stack version
- Some stack versions require new instance configurations

```bash
# Check available stack versions in ECE
curl -s -k -u admin:<pass> "https://localhost:12443/api/v1/stack/versions" | jq '[.[].version]'
```

### 9. Operational Limits at Scale
| Scale limit | Guidance |
|---|---|
| Allocator instances | No hard limit; practical limit ≈ 200 instances per allocator |
| Deployments per ECE | Depends on coordinator resources; 100s of deployments typical |
| Plan changes in parallel | Constructor queues them; avoid running > 10 simultaneously |
| ZK node limit | ZK stores metadata; very large ECE installations (500+ deployments) may need ZK tuning |

### 10. KCS + Docs Lookup
Execute retrieval protocol with the ECE version, the specific symptom, and whether it appeared after an upgrade or environmental change.

## Token Budget
- KCS is the primary source — known issues are often already documented.
- Always include ECE version and OS version in the search.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
