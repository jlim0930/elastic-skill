# Error Pattern Matching

**Purpose**: Quick lookup of common error patterns to identify root cause and target sub-agent.

## Elasticsearch Errors
| Pattern | Likely Cause | Route To |
|---|---|---|
| `disk usage exceeded flood-stage` | Disk > 95% → index read-only | es/disk-storage-watermark |
| `circuit_breaking_exception` | Heap exhausted for request type | es/jvm-memory-gc |
| `rejected execution` / `429` | Thread pool saturated | es/indexing-performance or es/search-performance |
| `unassigned_shards` > 0 | Allocation blocked (disk, filtering, node loss) | es/shard-distribution or es/cluster-health |
| `failed to obtain shard lock` | Shard already active on node | es/cluster-health |
| `mapping_exception` / `illegal_argument` | Field type conflict | es/mapping-schema |
| `script_exception` / `NullPointerException` in script | Painless null pointer or type error | es/ingest-pipeline |
| `index_not_found_exception` | Index deleted or alias broken | es/ilm or es/cluster-health |
| `snapshot_in_progress_exception` | Concurrent snapshot conflict | es/snapshot-restore |
| `search_phase_execution_exception` | Query-time error (shard failure) | es/search-performance |

## Logstash Errors
| Pattern | Likely Cause | Route To |
|---|---|---|
| `Pipeline aborted due to error` | Config syntax or plugin load error | logstash/pipeline-startup-config |
| `WARN: Received an event that has a different character encoding` | Codec mismatch | logstash/filter-parsing |
| `Failed to index event, retrying` | ES output rejected | logstash/elasticsearch-output |
| `PQ is full` | Persistent queue saturated | logstash/queueing-backpressure |
| `Grok pattern not found` / `grok failed` | Pattern mismatch | logstash/filter-parsing |
| `Connection refused` to ES | ES unreachable from Logstash | cross-product/network |
| `LoadError` / `PluginLoadingError` | Plugin incompatible post-upgrade | logstash/plugin-compatibility |

## Kibana Errors
| Pattern | Likely Cause | Route To |
|---|---|---|
| `Kibana server is not ready yet` | ES connectivity or migration in progress | kibana/startup-availability |
| `FATAL: Unable to complete migration` | Migration failure during upgrade | kibana/saved-objects-migration |
| `task manager` warn/error | Task manager overloaded | kibana/alerting-rules or kibana/performance |
| `is_missing_secrets: true` | Encryption key changed | kibana/alerting-rules |
| `Field is not aggregatable` | `text` field without `.keyword` | kibana/dashboard-visualization |
| `No data` in visualization | Wrong data view, time range, or DLS | kibana/discover-query |
| `chromium` / `launch failed` | Headless browser issue for reporting | kibana/reporting |

## TLS / Auth Errors (Cross-Component)
| Pattern | Likely Cause | Route To |
|---|---|---|
| `SSLHandshakeException` | CA trust failure | cross-product/certificate-tls |
| `unable to verify first certificate` | Incomplete CA chain | cross-product/certificate-tls |
| `hostname verification failed` | SAN mismatch | cross-product/certificate-tls |
| `401` on all requests | Wrong credentials or expired token | es/security-access |
| `403` on index | Role missing index privilege | es/security-access |

## OS / Platform Errors
| Pattern | Likely Cause | Route To |
|---|---|---|
| `max file descriptors` | ulimit too low | cross-product/os-platform |
| `max virtual memory areas vm.max_map_count` | Not set to 262144 | cross-product/os-platform |
| `OOM killer` / `killed` in dmesg | Container memory limit exceeded | cross-product/os-platform |
| `no space left on device` | Disk full or inode exhaustion | es/disk-storage-watermark |
