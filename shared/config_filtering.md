# Config Filtering

**Purpose**: Extract only the relevant config sections for the current issue. Ignore defaults and unrelated settings.

## Principle
Load the minimum config needed to answer one question. Do not scan entire config files.

## Config Locations by Component
| Component | Config Path |
|---|---|
| Elasticsearch | `/etc/elasticsearch/elasticsearch.yml` |
| Kibana | `/etc/kibana/kibana.yml` |
| Logstash | `/etc/logstash/logstash.yml`, `/etc/logstash/conf.d/*.conf` |
| Filebeat | `/etc/filebeat/filebeat.yml` |
| Elastic Agent | `/etc/elastic-agent/elastic-agent.yml` |
| Fleet Server | Config in Fleet UI or policy YAML |

## Extract by Issue Type
| Issue | Keys to Extract |
|---|---|
| TLS | `ssl`, `certificate`, `key`, `ca`, `truststore`, `keystore` |
| Auth | `xpack.security`, `authc`, `realm`, `api_key`, `username`, `password` |
| Memory/Heap | `Xms`, `Xmx`, `bootstrap.memory_lock`, `jvm.options` |
| Disk | `path.data`, `path.logs`, watermark settings |
| Network | `network.host`, `http.port`, `transport.port`, `discovery.seed_hosts` |
| ILM | `indices.lifecycle`, `rollover`, `policy` |
| Ingest pipeline | `pipeline`, `processors`, `on_failure` |
| Output (Logstash) | `output`, `hosts`, `index`, `data_stream`, `api_key`, `ssl` |
| Kibana connectivity | `elasticsearch.hosts`, `elasticsearch.ssl`, `server.host`, `server.port` |

## Comparison Approach
- Compare the running config against documented defaults
- Look for values that deviate from defaults — these are the candidates
- If a setting is missing, it defaults to the documented value (confirm before assuming misconfiguration)

## Validation Steps
1. Identify the setting in question
2. Confirm its current value (explicitly set vs. default)
3. Compare against the expected value for the use case
4. Check for conflicts (e.g., two settings that override each other)

## Common Config Mistakes
- TLS enabled in one direction but not the other
- Credentials referencing wrong user role
- `discovery.seed_hosts` not listing all master-eligible nodes
- `path.data` pointing to wrong or full disk
- Logstash output `index` conflicting with `data_stream: auto`
- Kibana `server.publicBaseUrl` missing or wrong
