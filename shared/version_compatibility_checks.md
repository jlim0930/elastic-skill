# Version Compatibility Checks

**Purpose**: Verify version alignment across Elastic Stack components and identify upgrade blockers.

## Compatibility Rules
| Component | Rule |
|---|---|
| ES node ↔ ES node | Same major.minor during rolling upgrade |
| Kibana ↔ ES | Must match major.minor exactly |
| Logstash → ES | Can be up to 1 minor behind ES |
| Beats/Agent → ES | Can be up to 1 minor behind ES |
| CCS local ↔ remote | Older can query newer; not vice versa |

## Step 1 — Inventory Current Versions
Collect: ES version (all nodes), Kibana, Logstash, Beats/Agent versions.
Look for mixed versions — expected during rolling upgrade, unexpected otherwise.

## Step 2 — Check Deprecation Log
Before any major upgrade, scan the deprecation log for:
- Frequency of each deprecation (highest count = highest risk)
- Settings that are removed in the target version
- API patterns that are removed or changed

All deprecations must be resolved before upgrading to the next major version.

## Step 3 — Index Compatibility
ES cannot read indices created more than 1 major version ago:
- ES 8.x cannot read indices from ES 6.x or earlier
- ES 9.x cannot read indices from ES 7.x or earlier

Check index creation versions and reindex incompatible indices before upgrade.

## Step 4 — Rolling Upgrade Order
**Correct order**: ES (one node at a time) → Kibana → Logstash → Beats/Agent

Before each ES node restart:
1. Disable shard allocation (primaries only)
2. Perform a synced flush
3. Upgrade the node
4. Wait for node to rejoin
5. Re-enable shard allocation
6. Wait for cluster green before next node

## Step 5 — Plugin Compatibility
- Update all Logstash plugins after a Logstash version upgrade
- ES plugins must match the ES version
- Confirm third-party plugins support the target version before upgrading

## Key Breaking Changes (7.x → 8.x)
| Area | Change |
|---|---|
| Security | Required by default (cannot disable) |
| TLS | Required on transport layer |
| `_type` | Removed entirely |
| Index templates | Legacy `_template` → composable `_index_template` |
| Node roles | `node.master`, `node.data` → `node.roles` list |
| Beats SSL | `ssl: true` → `ssl_enabled: true` |
| Logstash Beats input | `cacert` → `ssl_certificate_authorities` |
