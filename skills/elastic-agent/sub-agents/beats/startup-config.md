---
name: beats-startup-config
description: Diagnoses Beats (Filebeat/Metricbeat/etc.) fails to start, YAML syntax/config errors, invalid module/input settings, path/permission issues, keystore/secret resolution failures, and deprecated config options after upgrade.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# Beats — Startup & Configuration Sub-Agent

Scope: Beat fails to start, YAML syntax/config parsing errors, invalid module/input settings, path/permission issues, keystore/secret resolution failures, deprecated config options after upgrade.

## Retrieval Protocol
Follow [../../../../shared/retrieval-protocol.md](../../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"filebeat failed to start config error"`, `"beats YAML syntax error"`, `"beats keystore secret failed"`, `"beats deprecated config upgrade"`, `"metricbeat module invalid config"`.

## Diagnostic Steps

### 1. Startup Errors
```bash
# Filebeat
grep -E "ERROR|FATAL|error|failed.*start|config" /var/log/filebeat/filebeat | tail -30
journalctl -u filebeat --no-pager -n 30

# Metricbeat
grep -E "ERROR|FATAL" /var/log/metricbeat/metricbeat | tail -20
```

### 2. Config Validation
```bash
# Test config without starting
filebeat test config -c /etc/filebeat/filebeat.yml
metricbeat test config -c /etc/metricbeat/metricbeat.yml
auditbeat test config -c /etc/auditbeat/auditbeat.yml
```
Reports YAML syntax errors and invalid field names without starting the Beat.

### 3. YAML Syntax Errors
```bash
python3 -c "import yaml; yaml.safe_load(open('/etc/filebeat/filebeat.yml'))" && echo "YAML valid" || echo "YAML error"
```
Common YAML mistakes:
- Mixed tabs and spaces (YAML requires spaces only).
- Unquoted special characters (`:`, `{`, `}`).
- Incorrect indentation (multi-line values, list items).
- Trailing spaces after colons.

### 4. Permission Issues
```bash
# Check Beat user can read config
ls -la /etc/filebeat/filebeat.yml
# Check Beat user can read log files
ls -la /var/log/nginx/access.log 2>/dev/null
# Check Beat data/log directory permissions
ls -la /var/lib/filebeat/ /var/log/filebeat/
```
```bash
# What user is the Beat running as?
ps aux | grep filebeat | grep -v grep | awk '{print $1}'
```

### 5. Keystore / Secret Resolution
```bash
# List keystore keys
filebeat keystore list --c /etc/filebeat/filebeat.yml
# Test keystore
filebeat keystore show <key_name> -c /etc/filebeat/filebeat.yml
```
Config references like `${ES_PASSWORD}` or `${keystore.my_secret}` — if the keystore doesn't have the key, startup fails.
```bash
grep -E "\$\{.*\}" /etc/filebeat/filebeat.yml | head -10
```

### 6. Module/Input Validation
```bash
filebeat modules list
# Enable a module
filebeat modules enable nginx
# Test module config
filebeat test config -c /etc/filebeat/filebeat.yml -e --strict.perms=false
```
Invalid module config = Beat starts but the module doesn't collect.
```bash
grep -r "error\|invalid\|unknown" /etc/filebeat/modules.d/*.yml | head -10
```

### 7. Deprecated Config After Upgrade
```bash
grep -E "deprecated\|WARN.*deprecated\|unknown config" /var/log/filebeat/filebeat | tail -20
```
After upgrading Beats, some options may be renamed or removed.
Check release notes for the version jump and `filebeat test config` output.

### 8. Strict Permissions Check
```bash
# Beats refuse to start if config file is writable by other users
filebeat test config --strict.perms=false -c /etc/filebeat/filebeat.yml
# Fix permissions
chmod go-w /etc/filebeat/filebeat.yml
```

### 9. KCS + Docs Lookup
Execute retrieval protocol now with the specific error from startup logs.

## Token Budget
- `filebeat test config` is the fastest validation tool — run before reading logs.
- `grep` for ERROR/FATAL in logs — never read full Beat log file.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../../shared/output-format.md](../../../../shared/output-format.md).
Reference thresholds from [../../../../shared/thresholds.md](../../../../shared/thresholds.md).
