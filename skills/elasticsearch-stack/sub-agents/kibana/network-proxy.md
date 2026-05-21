---
name: kb-network-proxy
description: Diagnoses Kibana base path and rewriteBasePath misconfiguration behind reverse proxies, nginx/HAProxy WebSocket upgrade failures for Dev Tools Console, load balancer session stickiness issues, CORS errors, DNS/hostname resolution failures, and publicBaseUrl misconfiguration breaking alerting links.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Network / Proxy

**Purpose**: Identify why Kibana behind a reverse proxy has routing errors, broken WebSockets, or session issues, and prescribe the fix.

## Use When
- 404 errors or blank page behind reverse proxy
- Dev Tools Console not working (WebSocket failure)
- Alerting links or report URLs pointing to wrong hostname
- CORS errors when embedding Kibana

## Do Not Use When
- TLS cert errors → kibana/tls-certificates
- Login failing → kibana/login-authentication

## Inputs Needed
- Reverse proxy type (nginx, HAProxy, etc.)
- Base path configured (`server.basePath`)
- `server.rewriteBasePath` setting
- `server.publicBaseUrl` setting

## Diagnostic Logic

### Base Path Configuration
| Setting | Value | Behavior |
|---|---|---|
| `server.basePath` | `/kibana` | Kibana expects requests on `/kibana/...` |
| `server.rewriteBasePath: true` | — | Kibana strips the prefix itself |
| `server.rewriteBasePath: false` | — | Proxy must strip prefix before forwarding |

- **Double strip** = `rewriteBasePath: false` AND proxy also strips path → 404 on all routes
- **No strip** = `rewriteBasePath: true` AND proxy also passes prefix → 404 (path doubled)
- Rule: choose ONE place to strip the prefix — either Kibana OR the proxy, not both

### Required Proxy Headers
Headers that must reach Kibana:
- `Host` — required for virtual host routing
- `X-Forwarded-For` — real client IP
- `X-Forwarded-Proto` — `https` when TLS terminated at proxy

Headers that must NOT be stripped:
- `Authorization` — breaks basic auth and API key auth
- `kbn-xsrf` — required for all mutating Kibana API calls
- Cookie headers — breaks session management

### WebSocket Configuration (Dev Tools Console)
- Kibana uses WebSockets for Dev Tools Console live updates
- Missing WebSocket upgrade headers → `connection error` in Dev Tools Console

nginx must include:
- `proxy_http_version 1.1`
- `proxy_set_header Upgrade $http_upgrade`
- `proxy_set_header Connection "upgrade"`
- `proxy_read_timeout 600s` (long-running console queries need extended timeout)

### Load Balancer Sessions (Multi-Node Kibana)
- Kibana 7.7+ stores sessions in ES (`.kibana_security_session_*` index)
- **Sticky sessions NOT required** for modern Kibana multi-node deployments
- Legacy 7.6 and below used in-memory sessions → sticky sessions were required then
- If session index exists and is healthy → no sticky session configuration needed

### CORS Issues
- Kibana does NOT natively support CORS configuration
- CORS errors from browser = API call from different origin than Kibana hostname
- Fix: use a reverse proxy to serve both frontend and Kibana API on same origin
- Or add CORS headers at the proxy level if cross-origin embedding is intended

### publicBaseUrl
- Required in Kibana 8.x; missing or wrong value causes:
  - Alert action URLs pointing to wrong hostname
  - Screenshot URLs wrong in reporting
  - Deep links in notifications broken
- Correct format: `https://kibana.example.com` (no trailing slash)
- Must be the exact URL that users see in their browser

### DNS Resolution
- Kibana server must resolve ES hostname (for `elasticsearch.hosts`)
- Chromium (for reporting) must resolve Kibana's own hostname to itself
- Set `xpack.reporting.kibanaServer.hostname` to a hostname Kibana can resolve to itself

## Shared Skills
→ [network_connectivity_checks](../../../../shared/network_connectivity_checks.md) — port reachability and DNS from Kibana host
→ [log_filtering](../../../../shared/log_filtering.md) — filter for proxy, basePath, WebSocket error patterns

## KCS Queries
`"kibana base path reverse proxy nginx misconfiguration 404"`, `"kibana websocket proxy upgrade nginx Dev Tools"`, `"kibana publicBaseUrl alerting report link wrong"`, `"kibana CORS error access-control"`

## Output
Report: proxy type, base path config issue, WebSocket missing headers, session or publicBaseUrl problem, fix.
