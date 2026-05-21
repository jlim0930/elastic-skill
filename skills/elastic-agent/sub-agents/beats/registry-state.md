---
name: beats-registry-state
description: Diagnoses Filebeat registry corruption, stale state causing re-reads or missed events, inode tracking issues after log rotation, registry growing too large, and state management after file moves or deletions.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — Registry & State Sub-Agent

Scope: Filebeat registry corruption, stale state causing re-reads or missed events, inode tracking after log rotation, registry growth, state cleanup after file moves/deletions.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat registry corruption"`, `"filebeat registry stale state"`, `"filebeat inode tracking rotation"`, `"filebeat re-reading file after restart"`, `"filebeat registry cleanup"`.

## Diagnostic Steps

### 1. Registry Location and Size
```bash
# Default registry path (varies by OS and version)
ls -lh /var/lib/filebeat/registry/filebeat/data.json 2>/dev/null || \
  ls -lh /var/lib/filebeat/registry 2>/dev/null

# Entry count (don't read full file — it can be huge)
jq 'length' /var/lib/filebeat/registry/filebeat/data.json 2>/dev/null
```
Registry contains one entry per tracked file. Large registries (>100k entries) slow startup.

### 2. Stale State — File Offset vs Actual Size
```bash
# Check offset for a specific file
jq '.[] | select(.source | test("/var/log/myapp")) | {source:.source, offset:.offset, timestamp:.timestamp}' \
  /var/lib/filebeat/registry/filebeat/data.json 2>/dev/null

# Compare with actual file size
wc -c /var/log/myapp/app.log
```
If offset > file size → file was truncated (copytruncate rotation) but Filebeat hasn't detected it.
If offset = file size → Filebeat thinks file is fully read. New lines should be picked up on next scan.

### 3. Inode Tracking After Rotation
Filebeat tracks files by inode (on Linux). After rotation:
```bash
# Check inode of current and rotated files
ls -li /var/log/nginx/access.log /var/log/nginx/access.log.1 2>/dev/null

# Check registry for inodes
jq '.[] | select(.source | test("/var/log/nginx")) | {source:.source, FileStateOS:.FileStateOS}' \
  /var/lib/filebeat/registry/filebeat/data.json 2>/dev/null
```
If the rotated file has a different inode than what's in the registry, Filebeat will re-read from the beginning.

### 4. Re-Reading Events After Restart
Problem: events duplicated after Filebeat restart.
Cause: registry was not flushed before shutdown (ungraceful stop).
```bash
grep -E "registry.*flush|flush.*registry|dirty.*close|shutdown" \
  /var/log/filebeat/filebeat | tail -10
```
Mitigation: `filebeat.shutdown_timeout: 5s` to allow registry flush on graceful stop.

### 5. Registry Corruption
```bash
# Test JSON validity
python3 -c "import json; json.load(open('/var/lib/filebeat/registry/filebeat/data.json'))" \
  && echo "Registry valid" || echo "Registry corrupted"
```
If corrupted:
1. Stop Filebeat
2. Delete registry: `rm -rf /var/lib/filebeat/registry/`
3. Start Filebeat — it will re-read all files from the beginning (expect duplicates)
4. Or set `ignore_older` to skip old content.

### 6. Registry Cleanup — Removing Stale Entries
Files that no longer exist accumulate in the registry.
```bash
# Find stale entries (files that don't exist)
jq -r '.[].source' /var/lib/filebeat/registry/filebeat/data.json 2>/dev/null \
  | while read f; do [ -f "$f" ] || echo "STALE: $f"; done | head -20
```
Configure automatic cleanup:
```yaml
filebeat.registry.flush: 1s
filebeat.registry.file_state_cleanup:
  remove_path_by_device: true  # Remove by inode when file is gone
clean_removed: true  # Remove state for deleted files
```

### 7. Missed Events After Log Rotation
If events are missed after rotation:
```bash
grep -E "close.*rename|renamed|rotated|inode.*change" /var/log/filebeat/filebeat | tail -10
```
Configure:
```yaml
close_renamed: false   # Keep reading renamed (rotated) file until EOF
scan_frequency: 5s    # Check for new/rotated files more frequently
ignore_older: 24h     # Don't read files older than 24h
```

### 8. Filebeat Version — Registry Format Changes
Filebeat 7.x changed registry format from a flat file to a directory structure.
After upgrading from 6.x → 7.x, old registry is migrated automatically.
```bash
ls -la /var/lib/filebeat/registry/ 2>/dev/null
# 7.x: registry/filebeat/data.json + meta.json
# 6.x: registry (flat file)
```
If migration failed: `grep "migrate\|registry" /var/log/filebeat/filebeat | head -10`

### 9. KCS + Docs Lookup
Execute retrieval protocol with the specific registry/state symptom.

## Token Budget
- `jq 'length'` first to gauge registry size before any inspection.
- Filter by specific file path using `jq .[] | select(.source | test(...))`.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
