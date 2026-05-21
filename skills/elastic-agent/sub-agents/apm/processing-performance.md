---
name: apm-processing-performance
description: Diagnoses APM Server processing performance issues including high CPU/memory, event drop rate, slow ES output, tail-based sampling overhead, aggregation pipeline bottlenecks, and APM Server resource sizing.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# APM Server — Processing & Performance Sub-Agent

Scope: High CPU/memory on APM Server, event drop rate, slow ES write throughput, tail-based sampling memory overhead, aggregation processing bottlenecks, resource sizing for APM Server.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"APM Server high CPU memory"`, `"APM Server dropping events"`, `"APM Server performance tuning"`, `"APM tail-based sampling memory"`, `"APM Server resource sizing"`.

## Diagnostic Steps

### 1. APM Server Resource Usage
```bash
ps aux | grep -E "apm-server|elastic-agent" | grep -v grep \
  | awk '{print "PID:"$2, "CPU:"$3"%", "MEM:"$4"%", "RSS:"int($6/1024)"MB"}'

# For Fleet-managed APM (subprocess)
pgrep -a apm-server 2>/dev/null | head -3
```
APM Server sizing guidelines (approximate):
- Low traffic (< 1k events/s): 2 vCPU, 4 GB RAM
- Medium traffic (< 10k events/s): 4 vCPU, 8 GB RAM
- High traffic (> 10k events/s): 8+ vCPU, 16+ GB RAM + multiple instances

### 2. Event Drop Rate
```bash
grep -E "drop.*event|event.*drop|overflow|queue.*full" \
  /var/log/apm-server/apm-server | tail -20
```
If APM Server is dropping events, it logs the reason. Check the internal metrics:
```bash
curl -s http://localhost:5066/stats | jq '{
  published: .output.events.active,
  dropped: .output.events.dropped,
  failed: .output.events.failed
}' 2>/dev/null
```

### 3. Elasticsearch Write Throughput
```bash
# Check ES bulk write performance
curl -s "http://localhost:9200/_cat/thread_pool/write?v&h=name,active,queue,rejected,completed"

# APM event indexing rate
curl -s "http://localhost:9200/_cat/indices/traces-apm*?v&h=index,docs.count,store.size&s=docs.count:desc" | head -5
```
ES write queue rejected > 0 = APM Server events not getting indexed fast enough.

### 4. Tail-Based Sampling Memory
Tail-based sampling buffers trace events in memory until a sampling decision is made:
```bash
grep -A10 "tail_sampling\|sampling:" /etc/apm-server/apm-server.yml 2>/dev/null
```
```yaml
# High-volume tail-sampling tuning
apm-server:
  sampling:
    tail:
      enabled: true
      policies:
        - sample_rate: 0.1
      storage_limit: 3GB   # increase if dropping traces
      ttl: 30s
```
Higher `storage_limit` = more memory usage but fewer dropped traces.

### 5. Aggregation Processing
APM Server generates service metrics and service maps via aggregation:
```bash
grep -E "aggregat|metric.*process|service.*map" /var/log/apm-server/apm-server | tail -10
```
Aggregations run in memory. Large number of unique services/endpoints increases memory footprint.

### 6. Go GC / Memory Pressure
```bash
curl -s http://localhost:5066/debug/vars 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
ms = d.get('memstats',{})
print('HeapAlloc:', ms.get('HeapAlloc',0)//1024//1024, 'MB')
print('NumGC:', ms.get('NumGC',0))
print('PauseTotal:', ms.get('PauseTotalNs',0)//1000000, 'ms')
"
```
Frequent GC pauses = APM Server memory pressure. Consider increasing available RAM or reducing event rate.

### 7. Concurrent Workers
```bash
grep -E "workers:|worker_count:|max_procs:" /etc/apm-server/apm-server.yml 2>/dev/null
```
Default: APM Server uses all available CPU cores (`GOMAXPROCS`). Cap if needed:
```bash
GOMAXPROCS=4 apm-server -c /etc/apm-server/apm-server.yml
```

### 8. Horizontal Scaling
Fleet-managed: add more APM integration instances or more Elastic Agents with APM policy.
Standalone: run multiple APM Server instances behind a load balancer, all pointing to the same ES.
```bash
# Each APM Server instance is stateless for head-based sampling
# For tail-based: all instances need access to the same Redis or ES-backed storage
```

### 9. KCS + Docs Lookup
Execute retrieval protocol with APM Server version, event rate, and observed resource metric.

## Token Budget
- `ps aux` + `curl /stats` for instant resource picture.
- `grep` for drop/overflow in logs before reading full file.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
