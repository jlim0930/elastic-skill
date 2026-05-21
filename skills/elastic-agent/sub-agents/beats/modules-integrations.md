---
name: beats-modules-integrations
description: Diagnoses Beats module and integration failures including module not enabled, module dashboard import failures, Metricbeat service connectivity issues, Filebeat module pipeline errors, and module variable/config overrides.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — Modules & Integrations Sub-Agent

Scope: Module not enabled, module dashboard import failures, Metricbeat service connectivity (MySQL/Redis/Nginx/etc.), Filebeat module ingest pipeline errors, module variable/config override failures.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat module not working"`, `"metricbeat module connection refused"`, `"beats module dashboard import failed"`, `"filebeat module pipeline error"`, `"metricbeat mysql module config"`.

## Diagnostic Steps

### 1. Module Enable Status
```bash
# Filebeat
filebeat modules list 2>/dev/null | grep -E "enabled|disabled"
ls /etc/filebeat/modules.d/*.yml | xargs grep -l "enabled: true" 2>/dev/null

# Metricbeat
metricbeat modules list 2>/dev/null
ls /etc/metricbeat/modules.d/*.yml | xargs grep -l "enabled: true" 2>/dev/null
```
A module `.yml.disabled` file = module is disabled. Enable with:
```bash
filebeat modules enable nginx
metricbeat modules enable mysql
```

### 2. Module Config Validation
```bash
# Test the module config without starting
filebeat test config -c /etc/filebeat/filebeat.yml -e --strict.perms=false 2>&1 | head -30
metricbeat test config -c /etc/metricbeat/metricbeat.yml 2>&1 | head -30
```

### 3. Metricbeat Service Connectivity
```bash
# Check module-specific connectivity
metricbeat test modules system 2>/dev/null
metricbeat test modules nginx 2>/dev/null

# Manual connection test to monitored service
curl -s http://localhost/nginx_status 2>/dev/null | head -5  # nginx stub_status
mysql -h 127.0.0.1 -u root -e "SHOW STATUS;" 2>/dev/null | head -5
redis-cli -h 127.0.0.1 ping 2>/dev/null
```

Module connection errors:
```bash
grep -E "error.*module|module.*error|connection.*refused.*module|failed.*fetch" \
  /var/log/metricbeat/metricbeat | tail -20
```

### 4. Module Variable Overrides
Modules use variables defined in the module `.yml` file:
```bash
cat /etc/filebeat/modules.d/nginx.yml
cat /etc/metricbeat/modules.d/mysql.yml
```
Common variable issues:
- `var.paths` not pointing to the actual log file location
- `var.hosts` pointing to wrong host/port
- `var.username`/`var.password` not set for authenticated services

Override via config file:
```yaml
# In metricbeat.yml
metricbeat.modules:
  - module: mysql
    hosts: ["tcp(127.0.0.1:3306)/"]
    username: metrics_user
    password: "${MYSQL_PASS}"
```

### 5. Ingest Pipeline Setup
Filebeat modules include ingest pipelines that must be loaded into Elasticsearch:
```bash
# Load pipelines (usually done on setup)
filebeat setup --pipelines -c /etc/filebeat/filebeat.yml

# Check if pipeline exists in ES
curl -s "http://localhost:9200/_ingest/pipeline/filebeat-*-nginx-access*" \
  | jq 'keys'
```
If pipeline is missing, events will be indexed without parsing.

### 6. Dashboard Import Failures
```bash
filebeat setup --dashboards -c /etc/filebeat/filebeat.yml 2>&1 | tail -20
```
Dashboard setup failures are non-critical — they don't affect data collection.
Common causes: Kibana not reachable, Kibana version incompatibility, index pattern already exists with conflicts.

### 7. Index Template Setup
```bash
filebeat setup --index-management -c /etc/filebeat/filebeat.yml 2>&1 | tail -20

# Verify template exists
curl -s "http://localhost:9200/_index_template/filebeat-*" | jq 'keys'
```

### 8. Filebeat Module Log Path Issues
```bash
# Check what paths the module is configured to use
grep -r "var.paths\|paths:" /etc/filebeat/modules.d/*.yml 2>/dev/null

# Confirm files exist at those paths
ls -la /var/log/nginx/access.log /var/log/nginx/error.log 2>/dev/null
```

### 9. Auditbeat System Module
```bash
grep -E "system.*module|auditd.*error|file.*integrity" /var/log/auditbeat/auditbeat | tail -10
# Auditbeat requires root for system module
id
```

### 10. KCS + Docs Lookup
Execute retrieval protocol with the module name and specific error.

## Token Budget
- `filebeat test config` before reading any log or config file.
- `metricbeat test modules <name>` for connectivity issues — instant signal.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
