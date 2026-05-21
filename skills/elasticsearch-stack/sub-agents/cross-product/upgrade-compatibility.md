---
name: cross-upgrade-compatibility
description: Diagnoses cross-product upgrade issues including version skew between Elasticsearch, Kibana, Logstash, Beats, and Elastic Agent, breaking changes identified from deprecation logs, rolling upgrade blockers such as old index format incompatibility, plugin compatibility failures post-upgrade, Kibana saved object migration failures during upgrade, and index compatibility for indices created more than one major version ago.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Cross-Product — Upgrade / Compatibility

**Purpose**: Identify version skew, breaking changes, and upgrade blockers across the Elastic Stack, and prescribe the correct upgrade sequence or remediation.

## Use When
- Component fails after upgrade (Kibana not starting, Logstash plugins failing)
- Mixed-version cluster stuck mid-upgrade
- Breaking changes causing runtime errors post-upgrade
- Planning upgrade from 7.x to 8.x or any major version jump

## Do Not Use When
- Component is failing for non-upgrade reasons → use that component's sub-agent
- Kibana migration failure (not during upgrade) → kibana/saved-objects-migration

## Inputs Needed
- Current version of each component (ES, Kibana, Logstash, Beats, Agent)
- Target version
- Any error messages from logs post-upgrade
- Whether this is a rolling upgrade (still in progress) or completed upgrade

## Diagnostic Logic

### Version Compatibility Rules
| Component Pair | Rule |
|---|---|
| ES node ↔ ES node | Must be same major.minor during rolling upgrade |
| Kibana ↔ ES | Kibana must match ES **major.minor exactly** |
| Logstash → ES | Logstash can be up to 1 minor version behind ES |
| Beats/Agent → ES | Beats can be up to 1 minor version behind ES |
| CCS: remote ↔ local | Older cluster can query newer; not vice versa |

Version skew impact:
- Kibana major.minor mismatch → Kibana startup failure or API errors
- Logstash plugin mismatch post-upgrade → `LoadError` or `NoMethodError` at startup
- Beats major version mismatch → index template conflicts and field type errors

### Rolling Upgrade Order
Correct sequence: **ES (one node at a time) → Kibana → Logstash → Beats/Agent**

Rolling upgrade steps per ES node:
1. Disable shard allocation before stopping node (`allocation.enable: primaries`)
2. Stop the node and upgrade the package
3. Start the node; verify it rejoins the cluster
4. Re-enable shard allocation (`allocation.enable: all`)
5. Wait for cluster to return to green before proceeding to next node

A mixed-version cluster is **expected** during the upgrade. A stuck mixed-version cluster = allocation left disabled or a node failed to rejoin.

### Rolling Upgrade Blockers
| Symptom | Cause | Fix |
|---|---|---|
| Cluster stays yellow after node restart | Shard allocation still disabled | Re-enable allocation |
| New node version shows unassigned shards | Old index format incompatibility | Reindex old indices first |
| Node refuses to join cluster | Major version skipped | Cannot skip major versions in ES |
| Index cannot be read after upgrade | Index created 2+ major versions ago | Reindex before upgrading |

**Index compatibility**: ES cannot read indices created more than 1 major version ago.
- ES 8.x cannot read indices created on ES 6.x or earlier
- ES 9.x cannot read indices created on ES 7.x or earlier
- Solution: reindex to a new index before upgrading

### Breaking Changes — 7.x → 8.x
| Area | 7.x Behavior | 8.x Change |
|---|---|---|
| Security | Optional (`xpack.security.enabled`) | Enabled by default; cannot disable on basic |
| TLS (transport) | Optional | Required |
| Index templates | `_template` (legacy) | `_index_template` (composable) — legacy still works but deprecated |
| `_type` | Deprecated | Fully removed |
| `node.master` / `node.data` | Valid settings | Renamed to `node.roles: [master]` / `[data]` |
| Script types | `inline` and `stored` | `inline` only by default |

### Deprecation Log Analysis
- Check `elasticsearch_deprecation.log` for all warnings before upgrading
- Address ALL deprecations before upgrading to the next major version
- Sort by frequency to prioritize: count occurrences of each deprecation type
- Kibana also logs deprecations — check kibana.log for deprecated API usage

### Plugin Compatibility Post-Upgrade
- Update ALL Logstash plugins after a Logstash upgrade (not just the one causing errors)
- ES plugins (e.g., repository-s3) must be reinstalled after each ES upgrade
- Plugin errors: `LoadError`, `NameError`, `NoMethodError`, `PluginLoadingError` in Logstash log

### Kibana Saved Object Migration During Upgrade
Migration stages: `INIT → WAIT_FOR_YELLOW_SOURCE → REINDEX → CLONE → UPDATE_MAPPINGS → UPDATE_ALIASES → DONE`

| Stuck Stage | Cause | Fix |
|---|---|---|
| `WAIT_FOR_YELLOW_SOURCE` | `.kibana` index is RED | Fix ES cluster health first |
| `REINDEX` | ES reindex slow or capacity issue | Check `_tasks` API; fix ES capacity |
| `UPDATE_TARGET_MAPPINGS` | Disk watermark or write block | Free disk; clear write block |
| Never reaches DONE | ES version mismatch with Kibana | Ensure exact major.minor match |

### Pre-Upgrade Checklist
Before starting upgrade, verify:
1. Cluster health is green (no unassigned shards)
2. No old indices (created 2+ major versions ago)
3. All deprecations reviewed and addressed
4. Snapshots taken of all data and `.kibana` index
5. Kibana target version matches ES target version

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for DEPRECATION, LoadError, migration stage keywords, version mismatch errors
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify post-upgrade errors before routing to component sub-agent

## KCS Queries
`"elastic stack upgrade version skew compatibility matrix rolling"`, `"elasticsearch breaking changes 7 to 8 upgrade security TLS"`, `"kibana saved object migration stuck REINDEX upgrade"`, `"logstash plugin LoadError after upgrade compatibility"`

## Output
Report: version inventory, compatibility violation (if any), breaking change identified, upgrade blocker (stuck allocation / old index / plugin), and fix or correct upgrade sequence.
