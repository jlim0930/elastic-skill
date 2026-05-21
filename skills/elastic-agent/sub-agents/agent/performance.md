---
name: agent-performance
description: Diagnoses Elastic Agent high CPU/memory usage, endpoint/input subprocess resource spikes, backpressure from outputs, slow event forwarding, large policy causing overhead, too many integrations on one host, and resource contention with host workloads.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Elastic Agent — Performance & Resource Sub-Agent

Scope: high CPU by Elastic Agent, high memory usage, endpoint/input subprocess resource spikes, backpressure from outputs, slow event forwarding, large policy causing overhead, too many integrations on one host, resource contention with host workloads.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"elastic-agent high CPU usage"`, `"elastic-agent high memory"`, `"elastic-agent backpressure output"`, `"elastic-agent too many integrations"`, `"elastic-agent resource contention"`.

## Diagnostic Steps

### 1. CPU and Memory Usage
```bash
ps aux --sort=-%cpu | grep elastic | grep -v grep | head -20
# Per-subprocess breakdown
ps aux --sort=-%cpu | grep -E "elastic-agent|filebeat|metricbeat|endpoint|osquerybeat" | grep -v grep
```
```bash
# Resource over time
top -b -n5 -d2 | grep -E "elastic-agent|endpoint" | tail -20
```

### 2. Identify High-Usage Subprocess
Elastic Agent runs subprocesses per integration (e.g., `filebeat`, `metricbeat`, `endpoint-security`, `osquerybeat`).
```bash
pgrep -a -f "elastic-agent|filebeat|metricbeat|endpoint|osquery" | awk '{print $1}' | while read pid; do
  ps -p $pid -o pid,ppid,pcpu,pmem,comm --no-headers 2>/dev/null
done | sort -k3 -rn | head -20
```
High CPU on `endpoint-security` = Endpoint Security scanning load.
High CPU on `filebeat` subprocess = large/many log files being harvested.

### 3. Backpressure from Outputs
```bash
grep -E "backpressure|queue.*full|output.*slow|429|too many requests" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
grep -E "429|backpressure|slow" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/filebeat-*.ndjson 2>/dev/null | tail -20
```
Backpressure = Elasticsearch output is rejecting or slow. Check ES write threadpool:
```bash
curl -s http://localhost:9200/_cat/thread_pool/write?v&h=name,active,queue,rejected
```

### 4. Slow Event Forwarding
```bash
grep -E "event.*forwarding|slow.*send|latency" \
  /opt/Elastic/Agent/data/elastic-agent-*/logs/elastic-agent-*.ndjson | tail -20
```
Symptoms: events accumulate in agent's internal queue, increasing memory usage.
Check network latency to Fleet Server and ES output:
```bash
ping -c 10 <fleet-server-host>
curl -w "@curl-format.txt" -o /dev/null https://<es-output>:9200/_cluster/health
```

### 5. Large Policy / Many Integrations
```bash
elastic-agent inspect --output json | jq '.inputs | length'
```
More than 20 inputs per agent = significant overhead. Consider:
- Splitting high-input hosts across multiple agents (if multiple Elastic Agents are supported).
- Reducing integrations on resource-constrained hosts.

### 6. Memory Usage Details
```bash
# Agent total RSS
cat /proc/$(pgrep -f "elastic-agent -c")/status | grep VmRSS
# Per subprocess
pgrep -f "elastic-agent|filebeat|metricbeat|endpoint" | while read pid; do
  awk '/VmRSS/{rss=$2} /Name/{name=$2} END{printf "%s RSS: %d kB\n", name, rss}' /proc/$pid/status 2>/dev/null
done | sort -t: -k2 -rn | head -10
```

### 7. Disk I/O (Log Harvesting)
```bash
iostat -x 2 5 | grep -v "^$"
lsof -p $(pgrep -f elastic-agent) 2>/dev/null | grep -c REG
```
Many open file handles = agent reading too many log files. Review `paths:` config in integrations.

### 8. Endpoint Security Resource Control
If `elastic-endpoint` is high CPU:
```bash
elastic-agent status --output json | jq '.components[] | select(.name | test("endpoint")) | {state:.state, message:.message}'
```
On very busy hosts, consider Endpoint Security exclusions for high-I/O paths.

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the specific subprocess and resource type (CPU/memory).

## Token Budget
- `ps aux --sort=-%cpu` for instant CPU ranking — no log reading needed.
- `grep` for backpressure keywords in logs — do not read full log files.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
