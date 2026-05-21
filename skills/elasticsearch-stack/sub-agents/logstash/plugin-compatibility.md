---
name: ls-plugin-compatibility
description: Diagnoses Logstash plugin version mismatch with Logstash version, deprecated settings causing warnings or startup failures, unsupported plugin behavior after Logstash upgrades, Java plugin dependency issues including JDBC driver problems, and codec/input/filter/output interoperability problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# LS — Plugin Compatibility

**Purpose**: Identify whether a plugin version, setting name, or codec is incompatible with the current Logstash version, and prescribe the fix.

## Use When
- `Unknown setting` or `LoadError` on startup after Logstash upgrade
- Plugin produces wrong output after upgrade
- JDBC driver class not found
- Codec mismatch causing parse errors

## Do Not Use When
- Config syntax error (not plugin-specific) → logstash/pipeline-startup-config
- Plugin installed but producing wrong events → logstash/filter-parsing

## Inputs Needed
- Logstash version (before and after if recently upgraded)
- Plugin name and version (`logstash-plugin list --verbose`)
- Specific error message (LoadError, NameError, deprecated setting name)
- Whether plugin is bundled or third-party/community

## Diagnostic Logic

### Post-Upgrade Plugin Failures
- After Logstash major version upgrade: bundled plugin versions may conflict with externally installed plugins
- Always update all plugins after a Logstash version upgrade: `logstash-plugin update`
- If update fails due to gem conflict: install a specific known-compatible version
- `LoadError` or `NameError` on startup = plugin gem version incompatible with current JRuby/Logstash

### Deprecated Settings by Version
| Upgrade | Common Deprecated Setting | Replacement |
|---|---|---|
| 7.x → 8.x | `ssl => true` (Beats input) | `ssl_enabled => true` |
| 7.x → 8.x | `cacert` in Beats input | `ssl_certificate_authorities => [...]` |
| 7.x → 8.x | `codec => json_lines` defaults changed | Verify explicit codec config |
| 6.x → 7.x | `type` field in output | Use `if [type] == ""` conditional |

- Deprecated settings produce `WARN` at startup — may still work for one version before removal
- Check startup log for WARN lines referencing `deprecated` or `removed`

### JDBC Driver Issues
- `ClassNotFoundException: <driver_class>` → JAR not found at `jdbc_driver_library` path
- `NoSuchMethodError` → JAR version incompatible with Logstash's JRuby JDK version
- Common driver class names:
  - PostgreSQL: `org.postgresql.Driver`
  - MySQL: `com.mysql.cj.jdbc.Driver`
  - Oracle: `oracle.jdbc.OracleDriver`
  - MS SQL: `com.microsoft.sqlserver.jdbc.SQLServerDriver`
- Verify JAR path exists and is readable; download compatible version if wrong

### Kafka Plugin Dependencies
- Logstash 8.x ships Kafka client 3.x by default
- Connecting to Kafka 2.x broker with Kafka client 3.x → check for protocol compatibility issues
- Verify `bootstrap_servers`, `security_protocol`, `sasl_mechanism` match broker requirements

### Codec Interoperability
| Setup | Problem | Fix |
|---|---|---|
| Beats input + `codec => json` | Double-decode (Beats already decodes JSON) | Remove codec — Beats sends structured data |
| TCP input + JSON events | No codec set → treats JSON as plain text | Add `codec => json` or `codec => json_lines` |
| `multiline` + one-JSON-per-line | Multiline merges partial JSON events | JSON events should be single-line; don't combine |
| S3 input + gzip files | Compressed file treated as text | Set `gzip => true` option; use `codec => plain` |

### Air-Gapped Plugin Installation
- Download gem on internet-connected machine; transfer to air-gapped host
- Install with `--no-verify` flag to skip gem server check
- Dependency gems must also be transferred if not already bundled

### Third-Party Plugin Compatibility
- Bundled (official) plugins: always compatible with same Logstash version
- Community plugins: check GitHub releases for explicit Logstash version compatibility
- When in doubt: test in a non-production environment before upgrading

## Shared Skills
→ [version_compatibility_checks](../../../../shared/version_compatibility_checks.md) — Logstash plugin version matrix guidance
→ [log_filtering](../../../../shared/log_filtering.md) — filter for LoadError, deprecated, NameError patterns

## KCS Queries
`"logstash plugin version mismatch incompatible upgrade"`, `"logstash deprecated setting removed upgrade"`, `"logstash JDBC driver ClassNotFoundException"`, `"logstash codec interoperability beats json"`

## Output
Report: plugin name, version conflict or deprecated setting, root cause, fix (update plugin / replace setting / correct codec / fix JAR path).
