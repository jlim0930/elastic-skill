# Question Clarification

**Purpose**: Collect the minimum required information to route and diagnose correctly.

## Use When
- The issue description is ambiguous or too broad
- Multiple sub-agents could match
- Key diagnostic inputs are missing

## Do Not Use When
- The issue is clearly described and routable
- The user has already provided logs, errors, and context

## Minimum Inputs Needed for Any Issue
1. **What is the symptom?** (error message, behavior, what's broken)
2. **Which component?** (ES, Kibana, Logstash, Fleet, APM, ECE, ECK, ECH)
3. **When did it start?** (sudden onset vs. gradual degradation)
4. **What changed recently?** (upgrade, config change, scaling, cert rotation)

## Additional Inputs by Issue Type
| Issue Type | Ask For |
|---|---|
| Performance | Baseline vs. current behavior; what changed; specific query or index |
| TLS/cert | Error message; which component to which component; cert source (certutil, internal CA, public CA) |
| Auth | Auth method; user or service account; exact error (401 vs. 403) |
| Cluster health | Status (red/yellow); unassigned shard count; recent changes |
| ILM | Policy name; phase stuck; failed step |
| Snapshot | Repository type; snapshot state; error message |
| Upgrade | Source version; target version; specific failure step |
| Kibana not loading | Error in browser console; Kibana log line; ES reachable? |

## Time Budget
- Ask at most 2–3 clarifying questions per round
- Do not ask more than necessary — start with best hypothesis if partial info is enough
- If after one round there's still insufficient info, state what's missing and return best hypothesis

## Format
Ask as a short bulleted list. Do not explain why you need each item unless the user asks.
