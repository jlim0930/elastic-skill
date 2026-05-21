---
name: kb-reporting
description: Diagnoses Kibana reporting jobs failing or stuck in pending, PDF/PNG generation failures due to headless Chromium browser issues, missing system libraries in containers, CSV export hitting size or timeout limits, reporting queue backlog from task manager overload, and security role restrictions blocking report generation.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Reporting

**Purpose**: Identify why reporting jobs are failing, stuck, or producing no output, and prescribe the fix.

## Use When
- Report jobs stuck in `pending` state
- PDF/PNG generation fails
- CSV export times out or truncates
- Reporting privilege errors

## Do Not Use When
- Task manager completely down → kibana/startup-availability (task manager drives reporting)
- Dashboard not loading (not reporting) → kibana/dashboard-visualization

## Inputs Needed
- Report type (PDF, PNG, CSV)
- Job status and error from `output.content`
- Whether issue is in all jobs or specific users
- Container environment (Docker/Kubernetes)

## Diagnostic Logic

### Job Status Classification
| Status | Meaning | Action |
|---|---|---|
| `pending` | Queued, waiting for worker | Check task manager health and worker count |
| `processing` | Currently generating | Normal; wait unless timeout expected |
| `completed` | Done | Download available |
| `failed` | Generation failed | Read `output.content` for error message |
| `completed_with_warnings` | Partial success | Check warnings in output |

### PDF/PNG — Chromium Issues
- PDF and PNG reports use bundled headless Chromium to render Kibana
- `Cannot launch` or `spawn failed` → Chromium binary missing or missing system libraries
- Missing libraries common in minimal container images (Alpine, distroless)
- Check for missing shared libraries by inspecting the Chromium binary dependencies

**Common missing libraries by OS:**
| Library | Debian Package | RHEL Package |
|---|---|---|
| `libnss3.so` | `libnss3` | `nss` |
| `libatk-1.0.so` | `libatk1.0-0` | `atk` |
| `libgbm.so.1` | `libgbm1` | `mesa-libgbm` |
| `libX11.so.6` | `libx11-6` | `libX11` |

**Sandbox issues in Docker/Kubernetes (no `--privileged`):**
- Set `xpack.screenshotting.browser.chromium.disableSandbox: true` in kibana.yml
- Required when running without Linux user namespaces or seccomp

**Memory:** Chromium requires ~150 MB per concurrent report job

### CSV Export Limits
| Setting | Default | Description |
|---|---|---|
| `xpack.reporting.csv.maxSizeBytes` | 10 MB | Max CSV file size |
| `xpack.reporting.csv.scroll_duration` | `30m` | Scroll keep-alive for large exports |
| `xpack.reporting.queue.timeout` | 120000 ms | Job timeout |

- CSV truncated → increase `maxSizeBytes`
- CSV times out → increase `queue.timeout` or optimize the ES query

### Reporting Queue Backlog
- Reporting jobs are processed by task manager workers
- Too many pending → task manager overloaded; scale Kibana nodes (each adds workers)
- Check task manager drift before assuming reporting-specific issue

### Network Access for Screenshots
- Kibana Reporting renders by calling its own HTTP/HTTPS endpoint internally
- Kibana must reach itself on its own `server.host:server.port`
- In network-restricted environments: allowlist Kibana's own IP and port
- Wrong `xpack.reporting.kibanaServer.hostname` → screenshots capture wrong page or fail

### Security Restrictions
- Required for PDF/PNG: `reporting: ["all"]` in user's Kibana role for target space
- Required for CSV: `reporting: ["all"]` OR built-in `reporting_user` role
- `reporting_user` also needs `read` on the data indices and `.reporting-*`

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for chromium, reporting, screenshot failure patterns
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — Kibana-to-self connectivity for screenshots

## KCS Queries
`"kibana reporting job failed PDF chromium"`, `"kibana chromium headless browser missing library container"`, `"kibana CSV export timeout maxSizeBytes"`, `"kibana reporting queue backlog task manager"`

## Output
Report: job type, status, Chromium error or CSV limit, network access issue, privilege gap, fix.
