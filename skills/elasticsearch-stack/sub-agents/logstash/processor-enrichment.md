---
name: ls-processor-enrichment
description: Diagnoses Logstash GeoIP enrichment failures and database update issues, DNS filter latency and caching, translate filter dictionary loading problems, fingerprint and deduplication logic errors, external lookup bottlenecks causing pipeline slowdown, and enrichment step ordering mistakes.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Processor / Enrichment

**Purpose**: Identify why enrichment is failing, producing no output, or slowing the pipeline, and prescribe the fix.

## Use When
- `_geoip_lookup_failure` on documents for public IPs
- DNS filter adding high per-event latency
- Translate filter producing `_translatefailure` tags
- Fingerprint/dedup not preventing duplicates

## Do Not Use When
- General Grok/date parsing failure → logstash/filter-parsing
- Enrichment slowdown is actually ES output backpressure → logstash/queueing-backpressure

## Inputs Needed
- Enrichment plugin type (GeoIP, DNS, translate, fingerprint)
- Failure tag or symptom
- Avg duration per event for the enrichment plugin (from Node Stats API)
- Database or dictionary path if applicable

## Diagnostic Logic

### GeoIP Issues
- `_geoip_lookup_failure` tag = IP not in database — **expected** for:
  - Private IP ranges (10.x, 172.16.x, 192.168.x)
  - Reserved/loopback (127.x, ::1)
- `_geoip_lookup_failure` on public IPs = database outdated or corrupted
- Elastic-managed auto-update (7.14+): check if downloader is enabled and running
- Self-managed: verify `.mmdb` file path exists and is a valid MaxMind database file

### DNS Filter Latency
- DNS filter is synchronous — each lookup blocks the pipeline worker
- High avg ms per event = DNS server is slow or unreachable
- Add caching to reduce repeated lookups: `hit_cache_size`, `failed_cache_size`, `hit_cache_ttl`
- Set `timeout` to prevent long stalls on unresolvable hostnames
- If DNS is still slow: run a local caching resolver (dnsmasq, systemd-resolved) as nameserver

### Translate Filter Issues
| Issue | Cause | Fix |
|---|---|---|
| `_translatefailure` tag | Key not in dictionary; no `fallback` set | Add `fallback => "unknown"` |
| Dictionary not loading | Invalid YAML format | Validate YAML syntax |
| Stale dictionary | `refresh_interval` too long | Reduce refresh interval |
| Case mismatch | Key uppercase in data, lowercase in dict | Mutate to lowercase before translate |

### Fingerprint / Deduplication
- Fields in `source` must be stable and deterministic — avoid ingestion timestamp
- `MURMUR3` = fast, not collision-resistant; use `SHA1` for stricter dedup
- Store fingerprint in `[@metadata][fingerprint]` (not indexed), then use as `document_id` in ES output
- Verify dedup works: check ES doc count after re-sending same events (count should not increase)

### Enrichment Field Ordering
- Filters execute in declaration order — must parse field BEFORE enriching with it
- GeoIP requires `source` field to exist; guard with `if [source][ip]`
- Skip private IPs before GeoIP lookup to avoid `_geoip_lookup_failure` noise

### External Lookup Bottleneck Detection
- Use Node Stats API plugin stats — find filters with avg `duration_ms / events_in` > 5ms
- If enrichment dominates pipeline duration:
  1. Add caching (DNS: `hit_cache_size`; translate: in-memory dictionary)
  2. Pre-compute enrichment at ingest time via ES ingest pipeline enrich processor
  3. Move enrichment to a separate downstream pipeline to decouple latency

## Shared Skills
→ [performance_triage](../../../../shared/performance_triage.md) — identify which pipeline layer is the bottleneck
→ [log_filtering](../../../../shared/log_filtering.md) — filter for enrichment failure tags

## KCS Queries
`"logstash geoip filter failed database lookup failure"`, `"logstash dns filter latency cache slow"`, `"translate filter dictionary logstash failure"`, `"fingerprint dedup logstash document_id elasticsearch"`

## Output
Report: enrichment plugin, failure tag or latency symptom, root cause (stale DB / no cache / ordering / invalid key), fix.
