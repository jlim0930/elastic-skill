# Elastic Stack AI Troubleshooting Ecosystem

A specialized set of AI agent skills, subagents, and utility scripts for diagnosing and remediating issues across the Elastic Stack — on self-managed infrastructure, Elastic Cloud Hosted (ECH), Elastic Cloud Enterprise (ECE), or Elastic Cloud on Kubernetes (ECK).

Designed for three goals: **fast diagnosis**, **accurate diagnosis**, and **low token usage**.

---

## How It Works

The system uses a three-layer routing architecture. No reference files are loaded until a route is confirmed.

### Layer 1 — Platform Detection
`elastic-expert` is the entry point. It scans the input for platform signals first and activates the appropriate platform skill before any domain analysis begins.

| Signal | Skill Activated |
|---|---|
| `ECE / allocator / ZooKeeper / FRC / route-server` | `ece-expert` |
| `ECK / Kubernetes / kubectl / pod / operator / CRD` | `eck-expert` |
| `Elastic Cloud / ECH / deployment plan / autoscaling` | `ech-expert` |
| No platform signal | `elastic-expert` handles directly |

### Layer 2 — Domain Routing (Phase 0)
Each platform skill scans for domain keywords before loading anything. A single match routes directly to the right specialist with only one reference file loaded alongside it.

| Domain Signal | Specialist Called |
|---|---|
| `certificate / TLS / SSL / keystore` | @elastic-certificate-specialist |
| `ILM / rollover / tier / lifecycle / data stream` | @elastic-ilm-specialist |
| `snapshot / SLM / backup / restore` | @elastic-snapshot-specialist |
| `APM / trace / span / sourcemap` | @elastic-apm-specialist |
| `Fleet / enrollment / Fleet Server / agent policy` | @elastic-fleet-specialist |
| `ML / anomaly / ELSER / trained model` | @elastic-ml-specialist |
| `Kibana / dashboard / visualization` | @elastic-kibana-specialist |
| `upgrade / deprecation / Upgrade Assistant` | @elastic-upgrade-specialist |
| `CCS / CCR / cross-cluster / remote cluster` | @elastic-ccs-ccr-specialist |
| `ingest pipeline / grok / Logstash / Painless` | @elastic-ingest-specialist |
| `transform / pivot / rollup` | @elastic-transform-specialist |
| `RBAC / SAML / OIDC / API key / 401 / 403` | @elastic-security-specialist |
| `GC / heap / slow search / indexing latency` | @elastic-performance-tuner |
| `diagnostic bundle / nodes_stats / cluster_state` | @elastic-diagnostics-specialist |
| `elasticsearch.log / kibana.log / gc.log / log file` | @elastic-log-analyzer |
| `deployment plan / autoscaling / console signal` | @elastic-cloud-specialist |
| `App Search / Workplace Search / Crawler` | @elastic-enterprise-search-specialist |

**1 match** → specialist called directly, one reference file loaded.
**2+ matches or no match** → full platform-specific triage (7–9 phases).

### Layer 3 — Specialist Agents
Each of the 17 specialists loads only `skills/shared/base.md` (universal thresholds, redaction rules, research guidance) plus one domain reference file. No orchestrator overhead.

---

## Platform Skills

| Skill | Platform | Triage Coverage |
|---|---|---|
| `elastic-expert` | Self-managed / all platforms (orchestrator) | 8-phase triage + output |
| `ece-expert` | Elastic Cloud Enterprise | 9 phases including container runtime, OS, ZooKeeper |
| `eck-expert` | Elastic Cloud on Kubernetes | 7 phases including K8s/operator layer |
| `ech-expert` | Elastic Cloud Hosted | 6-step inline triage + autoscaling checks |

Platform skills with internal routing (ECE/ECK): ECE-specific signals (ZooKeeper, proxy, Docker, Podman, OS) and ECK-specific signals (operator, CNI, Ingress, pod scheduling) are handled internally without calling a specialist — these are platform-layer issues with no cross-platform equivalent.

---

## Shared Reference Library

All specialists reference files from `skills/shared/` — a single canonical copy instead of per-skill duplicates:

| File | Loaded By |
|---|---|
| `base.md` | All 17 specialist agents on start |
| `advanced-features.md` | Certificate, APM, ML, Security specialists |
| `data-management.md` | ILM, Snapshot, CCS/CCR, Transform specialists |
| `ingest-pipelines.md` | Fleet, Ingest specialists |
| `commands.md` | Performance, Diagnostics specialists |

---

## Utility Scripts

Run via `run_shell_command` to extract signals from large diagnostic files without loading them fully into context:

| Script | Input | Purpose |
|---|---|---|
| `triage_summary.sh` | Diagnostic directory | High-level cluster overview |
| `triage_json.sh` | JSON file | Health, disk, shards, ILM errors |
| `triage_logs.sh` | Log file | Top exception distribution |
| `triage_memory.sh` | nodes_stats.json | JVM heap pressure + circuit breakers |
| `triage_circuit_breakers.sh` | nodes_stats.json | Breaker state and usage |
| `triage_allocation.sh` | cat/shards JSON | Unassigned shard reasons |
| `triage_sharding.sh` | cat/shards JSON | Shard size and distribution |
| `triage_tasks.sh` | _tasks JSON | Longest-running tasks |
| `triage_hot_threads.sh` | hot_threads text | Top CPU thread summary |
| `triage_pipelines.sh` | nodes_stats.json | Ingest processor failures |
| `triage_ilm.sh` | ILM status + policies JSON | ILM status and policy summary |

---

## Quick Start

```bash
./setup.sh
```

Installs agents and skills globally for Claude CLI, Gemini CLI, and Cursor IDE. Makes all utility scripts executable.

### Claude CLI

```bash
claude
```

Skills and agents are installed to `~/.claude/`. Ask any Elastic Stack question — `elastic-expert` routes to the right specialist automatically.

### Gemini CLI

```bash
gemini
```

Agents and skills installed to `~/.gemini/`. Same routing behavior as Claude CLI.

### Cursor IDE

Navigate to your troubleshooting directory and run:

```bash
elastic-cursor-init
```

This symlinks all agent rules to `.cursor/rules/`. Use `@elastic-log-analyzer`, `@elastic-performance-tuner`, etc. in Cursor Chat to invoke specialists directly.

> Run `elastic-cursor-init` from the `elastic-skill` project directory for full path resolution of reference files.

### Web LLM (Claude.ai / ChatGPT)

See `BOOTSTRAP.md` — upload all files from `skills/shared/` and `skills/elastic-expert/references/` as knowledge base documents, then paste the master system prompt.

---

## Repository Structure

```
elastic-skill/
├── setup.sh                           # Universal installer
├── BOOTSTRAP.md                       # Web LLM setup (Claude.ai / ChatGPT)
├── agents/                            # 17 specialist agent definitions
│   ├── elastic-certificate-specialist.md
│   ├── elastic-ilm-specialist.md
│   ├── elastic-snapshot-specialist.md
│   ├── elastic-apm-specialist.md
│   ├── elastic-fleet-specialist.md
│   ├── elastic-ml-specialist.md
│   ├── elastic-kibana-specialist.md
│   ├── elastic-upgrade-specialist.md
│   ├── elastic-ccs-ccr-specialist.md
│   ├── elastic-ingest-specialist.md
│   ├── elastic-transform-specialist.md
│   ├── elastic-security-specialist.md
│   ├── elastic-performance-tuner.md
│   ├── elastic-diagnostics-specialist.md
│   ├── elastic-log-analyzer.md
│   ├── elastic-cloud-specialist.md
│   └── elastic-enterprise-search-specialist.md
├── scripts/                           # 11 bash scripts for fast diagnostic parsing
└── skills/
    ├── shared/                        # Canonical reference files (no per-skill duplicates)
    │   ├── base.md                    # Thresholds, redaction, research, efficiency rules
    │   ├── advanced-features.md       # ML, APM, Security
    │   ├── commands.md                # ES API, K8s, ECE, OS commands
    │   ├── data-management.md         # ILM, Snapshots, CCS/CCR, Transforms
    │   └── ingest-pipelines.md        # Ingest pipelines, Beats, OTel
    ├── elastic-expert/                # Self-managed orchestrator + triage sequence
    ├── ece-expert/                    # ECE platform skill
    ├── eck-expert/                    # ECK/Kubernetes platform skill
    └── ech-expert/                    # Elastic Cloud Hosted skill
```

---

## Official Resources

All agents follow a Primary Source Protocol — web search and fetch tools are used to verify against:

- **Documentation**: https://www.elastic.co/docs
- **API Reference**: https://www.elastic.co/docs/api/
- **Source & Issues**: https://github.com/elastic
- **Agent Skills**: https://github.com/elastic/agent-skills
