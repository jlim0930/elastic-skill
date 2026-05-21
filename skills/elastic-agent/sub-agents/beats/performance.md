---
name: beats-performance
description: Diagnoses Beats high CPU/memory usage, slow event throughput, harvester queue buildup, Metricbeat collection interval lag, Go runtime GC pressure, and system-level resource constraints affecting Beat performance.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — Performance Sub-Agent

Scope: High CPU/memory, slow event throughput, harvester queue buildup, Metricbeat collection lag, Go GC pressure, worker/batch configuration, system-level resource constraints.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat high CPU usage"`, `"beats performance tuning"`, `"filebeat slow throughput"`, `"metricbeat high memory"`, `"beats worker batch size tuning"`.

## Diagnostic Steps

### 1. Beat Resource Usage
```bash
# CPU and memory for all Beat processes
ps aux | grep -E "(filebeat|metricbeat|auditbeat|heartbeat|packetbeat)" | grep -v grep \
  | awk '{print $1, $2, "CPU:"$3"%", "MEM:"$4"%", "RSS:"int($6/1024)"MB", $11}'

# Over time
top -b -n3 -d1 -p $(pgrep -f filebeat | head -1) | grep -E "^[0-9]" | awk '{print "CPU:"$9, "MEM:"$10}'
```

### 2. Internal Metrics (Expvar / Monitoring)
```bash
# If HTTP endpoint is enabled (filebeat.monitoring.enabled: true or logging.metrics.enabled: true)
curl -s http://localhost:5066/stats | jq '{
  events: .filebeat.events,
  harvester: .filebeat.harvester,
  output: .output.events,
  pipeline: .pipeline.events
}'
```
Key metrics:
- `events.active` vs `events.added` drift = pipeline backpressure
- `harvester.open_files` = files currently being read
- `output.events.failed` = delivery failures causing retries

### 3. Queue Depth and Backpressure
```bash
curl -s http://localhost:5066/stats | jq '.pipeline.queue'
```
Queue full = harvesters stall. Increase queue size or fix output bottleneck:
```yaml
queue.mem:
  events: 8192       # increase from default 3200
  flush.min_events: 2048
  flush.timeout: 5s
```

### 4. Worker and Batch Size Tuning
```yaml
# Elasticsearch output performance
output.elasticsearch:
  worker: 4            # parallel output workers (default 1)
  bulk_max_size: 200   # events per bulk request (default 50 for filebeat, higher for metricbeat)
  compression_level: 3 # gzip compression (reduces bandwidth, adds CPU)
```
```bash
grep -A10 "output.elasticsearch:" /etc/filebeat/filebeat.yml | grep -E "worker|bulk|compress"
```
Rule: increase `worker` if ES can handle more concurrent bulk requests; increase `bulk_max_size` if throughput is the bottleneck.

### 5. Harvester Count
```bash
curl -s http://localhost:5066/stats | jq '.filebeat.harvester.open_files'
```
Too many open harvesters = high memory and file descriptor usage.
Limit with:
```yaml
filebeat.inputs:
  - type: log
    harvester_limit: 0   # 0 = unlimited (default). Set to N to cap concurrent harvesters.
    close_inactive: 5m   # Close harvesters for idle files
    close_timeout: 30m   # Force-close harvesters after this duration
```

### 6. Metricbeat Collection Interval
```bash
grep -E "period:|collection_period:" /etc/metricbeat/modules.d/*.yml | head -10
```
Metricbeat collects metrics at the configured `period` (default 10s). If collection takes longer than the period, metrics are delayed.
```bash
grep -E "took.*longer|collection.*slow|period.*exceeded" /var/log/metricbeat/metricbeat | tail -10
```
Solution: increase period, reduce modules/metricsets, or add more resources.

### 7. Go GC Pressure
```bash
curl -s http://localhost:5066/debug/vars | python3 -c "
import json,sys
d=json.load(sys.stdin)
ms = d.get('memstats',{})
print('HeapAlloc:', ms.get('HeapAlloc',0)//1024//1024, 'MB')
print('NumGC:', ms.get('NumGC',0))
print('PauseTotalNs:', ms.get('PauseTotalNs',0)//1000000, 'ms total GC pause')
"
```
High GC pause time = Beat spending significant time in garbage collection.
Tune Go GC via environment variable: `GOGC=200` (default 100) to reduce GC frequency at cost of more memory.

### 8. File Descriptor Limits
```bash
# Check fd usage for Beat process
PID=$(pgrep -f filebeat | head -1)
cat /proc/$PID/limits | grep "open files"
ls /proc/$PID/fd | wc -l
```
If near the limit:
```bash
ulimit -n 65536  # for current session
# Or in systemd unit file:
# LimitNOFILE=65536
```

### 9. Network Bandwidth
If Beats are sending large volumes:
```bash
# Check output compression
grep "compression" /etc/filebeat/filebeat.yml

# Estimate throughput
grep -E "total.*bytes|bytes.*sent|throughput" /var/log/filebeat/filebeat | tail -5
curl -s http://localhost:5066/stats | jq '.output.write.bytes'
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with Beat type, resource metric, and observed throughput.

## Token Budget
- Internal metrics endpoint (`/stats`) gives instant performance snapshot.
- `ps aux` for resource baseline before log analysis.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
