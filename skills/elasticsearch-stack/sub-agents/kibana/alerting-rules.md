---
name: kb-alerting-rules
description: Diagnoses Kibana alerts not firing, connector failures including missing secrets after encryption key change, rule execution delays from task manager backlog, action frequency and throttling confusion, privilege issues for rule execution, and detection engine rule failures.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Alerting & Rules

**Purpose**: Identify why an alert is not firing, a connector is failing, or rules are executing late, and prescribe the fix.

## Use When
- Rule status is `error` or `warning`
- Connector not sending notifications
- Rules executing late (high task manager drift)
- Alert rule not triggering despite conditions being met

## Do Not Use When
- Kibana not starting → kibana/startup-availability
- User cannot access alerting UI → kibana/authorization-spaces

## Inputs Needed
- Rule ID and execution status
- Connector type and error from execution log
- Task manager health (drift.p50, drift.p99)
- Whether rule was created by user with full privileges

## Diagnostic Logic

### Rule Status Classification
| Status | Meaning | Action |
|---|---|---|
| `ok` | Last execution succeeded | Check conditions and notify_when settings |
| `active` | Condition met; actions triggered | Normal; check action delivery if not received |
| `error` | Execution failed | Read `.error.message` from rule execution log |
| `warning` | Partial success (some actions failed) | Check connector errors |
| `pending` | Queued, not yet run | Check task manager health |

### Task Manager Health (First Check for Delayed Rules)
- `drift.p50` > 1000ms = Warning; rules executing noticeably late
- `drift.p99` > 5000ms = Critical; most rules significantly delayed
- High drift causes: too many rules, insufficient Kibana nodes, `.kibana_task_manager` index pressure
- Fix: reduce active rule count; add Kibana nodes; fix `.kibana_task_manager` ES health

### Connector Failures
| Connector Type | Common Cause | Fix |
|---|---|---|
| Email (SMTP) | Wrong credentials or TLS settings | Verify SMTP config; test manually |
| Slack webhook | URL changed or revoked | Update webhook URL |
| Jira/ServiceNow | API token expired | Regenerate token in connector config |
| Webhook | Kibana cannot reach target URL | Check firewall/egress from Kibana host |

- `is_missing_secrets: true` on connector = credentials encrypted with key that has changed
- Fix: re-enter credentials in Stack Management > Connectors (cannot recover old encrypted secrets)

### Action Frequency and Throttling
| `notify_when` | Behavior |
|---|---|
| `onActionGroupChange` | Fires only when alert transitions state (recommended) |
| `onActiveAlert` | Fires every execution while active (noisy) |
| `onThrottleInterval` | Fires at most once per throttle interval |

- `throttle: 1h` = action fires at most once per hour per alert instance; NOT every minute
- Common confusion: expecting continuous notifications when `onActionGroupChange` only fires on state change

### Privilege Issues for Rule Execution
- Kibana creates an API key per rule at creation time, scoped to creator's privileges
- If creator's role is later reduced → rule stops working with 403 errors
- Fix: delete and re-create the rule as a user with correct privileges (cannot update rule's API key)
- Required: `alerting: ["all"]` in Kibana + `read` on data indices + `manage` on `.alerts-*`

### Task Manager Index Health
- `.kibana_task_manager` index RED or full → rules cannot be scheduled or executed
- Fix ES cluster health for that index before diagnosing rule-level issues

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for alerting, rule execution, connector error patterns
→ [authentication_checks](../../../../shared/authentication_checks.md) — rule API key privilege verification

## KCS Queries
`"kibana alert not firing rule execution error"`, `"kibana connector failed missing secrets"`, `"task manager backlog alert delay drift"`, `"kibana rule execution privilege 403 API key"`

## Output
Report: rule status, connector error (if any), task manager drift, privilege gap (if any), fix.
