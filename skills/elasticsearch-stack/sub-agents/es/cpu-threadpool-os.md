---
name: es-cpu-threadpool-os
description: Diagnoses Elasticsearch high CPU, threadpool queue saturation and rejections, hot threads, load average spikes, file descriptor exhaustion, swap and memory locking issues, disk I/O bottlenecks, vm.max_map_count, and cgroup container resource limits.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — CPU / Threadpool / OS

**Purpose**: Identify whether CPU saturation, thread pool exhaustion, or OS misconfiguration is causing Elasticsearch performance degradation.

## Use When
- CPU > 80% sustained on ES nodes
- Thread pool showing queued or rejected requests
- OS settings flagged at startup (vm.max_map_count, file descriptors)
- Node behavior inconsistent in containers/cgroups

## Do Not Use When
- Heap/GC is the primary issue → es/jvm-memory-gc
- Disk is full → es/disk-storage-watermark
- Network connectivity errors → es/network-transport

## Inputs Needed
- CPU % per node
- Thread pool queue/rejected counts (all pools)
- OS limits (ulimit -n, sysctl vm.max_map_count, swap status)
- Container memory/CPU limits if applicable

## Diagnostic Logic

### CPU Saturation
- > 90% sustained = Critical — investigate immediately
- Spike during indexing → check write pool and merge activity
- Spike during search → check search pool and aggregation patterns
- Spike at no load → background GC or segment merge (see es/jvm-memory-gc)

### Thread Pool — Check All Pools for Rejections
Any `rejected > 0` = requests being dropped (HTTP 429).

| Pool | When Saturated |
|---|---|
| `write` | Bulk/index requests dropped |
| `search` | Search requests dropped (429) |
| `get` | Single-doc GET requests dropped |
| `management` | Cluster state updates blocked |
| `snapshot` | Snapshot operations queued |

Thread pool sizes are CPU-bound by design — cannot meaningfully increase without adding CPUs.

### Hot Thread Analysis
From hot threads output, identify by stack frame:
- `InternalEngine` → indexing/merge
- `org.elasticsearch.search` → search/aggregation
- `painless` → expensive script
- `java.util.regex` → expensive regex
- `ConcurrentMergeScheduler` → merge storm

### File Descriptors
- > 80% of max open = Warning
- Required: 65535 minimum (`LimitNOFILE=65535` in systemd)
- ES needs one FD per shard per segment per replica — oversharding increases FD use

### Swap / Memory Lock
- `mlockall: false` = heap can swap → unpredictable GC spikes
- Fix: `bootstrap.memory_lock: true` + `LimitMEMLOCK=infinity` in systemd
- Container environments may block `mlock` by security policy — check pod security context

### vm.max_map_count
- Must be ≥ 262144 (Lucene mmapped files)
- Set on the HOST kernel, not inside containers
- Missing → ES startup fails with explicit error message

### Container / Cgroup Limits
- CPU throttling at cgroup level appears as slow search without high CPU metric
- Check: `allocated_processors` vs `available_processors` on node
- If `allocated_processors` < actual: ES thread pools are undersized; set `node.processors` override
- Memory limit must accommodate JVM heap + off-heap (50% rule maximum)

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter hot_threads for high-% frames
→ [performance_triage](../../../../shared/performance_triage.md) — layer-by-layer bottleneck isolation

## KCS Queries
`"high CPU elasticsearch threadpool rejected"`, `"file descriptor exhaustion elasticsearch"`, `"swap memory lock elasticsearch mlockall"`, `"vm.max_map_count elasticsearch"`

## Output
Report: which pool is saturated, CPU% per node, OS setting violations, root cause, fix.
