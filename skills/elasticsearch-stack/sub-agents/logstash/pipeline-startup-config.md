---
name: ls-pipeline-startup-config
description: Diagnoses Logstash pipeline fails to start, syntax/config parsing errors, plugin option deprecations, multiple pipeline config conflicts, centralized pipeline management issues, environment variable substitution problems, and config reload failures.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Pipeline Startup & Config

**Purpose**: Identify why Logstash failed to start or a pipeline cannot load, and prescribe the fix.

## Use When
- Logstash fails to start (service not running)
- `Pipeline aborted` or `ConfigurationError` in logs
- Config reload failing silently
- Centralized pipeline management (CPM) not loading pipelines

## Do Not Use When
- Pipeline starts but events not flowing → logstash/input-connectivity or logstash/filter-parsing
- TLS error preventing startup → logstash/tls-certificates

## Inputs Needed
- Error message from `logstash-plain.log` at startup
- Config file(s) and structure (`conf.d/` or `pipelines.yml`)
- Whether CPM is enabled
- Environment variable names referenced in config

## Diagnostic Logic

### Error Classification
| Pattern | Meaning | Fix |
|---|---|---|
| `Expected one of` | Syntax error — missing brace or bad operator | Note file/line number; fix syntax |
| `Unknown setting` | Removed or renamed plugin option | Check plugin changelog for renamed key |
| `Pipeline aborted due to error` | Fatal error during startup | Check preceding ERROR lines |
| `Cannot parse variable` | Unset `${VAR}` with no default | Set the env var or add `:default` |
| `LoadError: No such file` | Plugin not installed | Install the missing plugin |

### First Check: Config Validation
- Use `--config.test_and_exit -f /etc/logstash/conf.d/` — validates without starting Logstash
- Reports first syntax error with file and line number
- Fastest path to diagnosing startup failures

### Common Syntax Mistakes
- Missing `=>` between option and value
- Unquoted strings with special characters
- Block comments `/* */` not supported — use `#` only
- Codec placed outside plugin block (codec must be inside input/output)

### Multiple Pipeline Conflicts
- Each `pipeline.id` in `pipelines.yml` must be unique
- Multiple pipelines sharing the same input port (e.g., Beats on 5044) → `BindException`
- Multiple pipelines on same Kafka topic without different `consumer_group` → duplicate events

### Centralized Pipeline Management (CPM)
- When CPM is enabled (`xpack.management.enabled: true`), local `conf.d/*.conf` files are IGNORED
- Pipeline configs come exclusively from Kibana > Management > Logstash Pipelines
- If Kibana is unreachable → Logstash cannot load any pipelines
- Check `xpack.management.elasticsearch.hosts` and credentials

### Environment Variable Substitution
- Syntax: `${VAR_NAME}` in config; default: `${VAR_NAME:default_value}`
- Unset variable without default → `ConfigurationError: Cannot parse variable`
- For systemd service: add env vars to systemd unit override (`Environment="MY_VAR=value"`)

### Config Hot Reload
- Hot reload applies when `config.reload.automatic: true` or when SIGHUP is sent
- Reload does NOT apply to `pipelines.yml` changes — those require a full restart
- If reload fails: check the reload error in logs; syntax errors in updated config abort the reload

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter startup log for ERROR/FATAL lines
→ [config_filtering](../../../../shared/config_filtering.md) — extract pipeline config structure

## KCS Queries
`"logstash pipeline failed to start config error"`, `"logstash unknown setting deprecated option"`, `"logstash environment variable substitution"`, `"logstash centralized pipeline management kibana"`

## Output
Report: error type (syntax/env/plugin/CPM), affected config file and line, fix.
