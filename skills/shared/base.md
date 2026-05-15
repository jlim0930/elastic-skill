# Elastic Stack — Shared Base Context

## Critical Thresholds
- JVM heap: >85% Critical | >75% Warning
- CPU: sustained >90% Critical
- Disk: near `flood_stage` = Critical | above `high_watermark` = Allocation Risk
- Cluster: `red` = primary shards unassigned | `yellow` = replicas missing
- Shards: <100MB = oversharded | >50GB search / >100GB logs = recovery/perf risk
- Confidence: **High** = explicit multi-source | **Medium** = strong, one source | **Low** = partial

## Redaction
Hostnames/IPs → `<node>`/`<host>` | Cluster IDs → `<cluster>` | Usernames → `<user>` | Namespaces → `<namespace>`

## Research
Verify syntax against `elastic.co/docs` before proposing. API: `elastic.co/docs/api/doc/elasticsearch`. Source/bugs: `github.com/elastic`.

## Efficiency
Files >1MB → `grep_search`. Repetitive tasks → create reusable script in `scripts/` and run via `run_shell_command` (skip if tool unavailable).
