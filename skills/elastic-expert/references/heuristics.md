# Heuristics and Thresholds

Use these values to determine severity and confidence.

## Confidence Labels
- **High**: Evidence is explicit and correlated across multiple sources.
- **Medium**: Evidence is strong but missing one secondary correlation.
- **Low**: Evidence is partial; requiring further specific artifacts.

## Critical Thresholds
- **Cluster Health**: `Red` is critical (primary shards unassigned). `Yellow` is warning (replicas missing).
- **JVM Heap**: >85% is Critical; >75% is Warning.
- **CPU**: Sustained >90% is Critical.
- **Disk**: Above `high watermark` is Allocation Risk; near `flood stage` is Critical.
- **Sharding**: 
    - Very high shard count per node = Stability Risk.
    - Tiny shards (<100MB) = Oversharding.
    - Very large shards (>50GB for search, >100GB for logs) = Recovery/Performance Risk.

## Redaction Rule
Always redact or generalize:
- Hostnames/IPs -> `<node>`, `<host>`, `<ip>`
- Cluster IDs -> `<cluster>`
- Usernames/Emails -> `<user>`
- Namespaces -> `<namespace>`
