---
name: kb-login-authentication
description: Diagnoses Kibana cannot log in with any auth method, SAML/OIDC/LDAP authentication failures, session expiration loops, cookie and secure cookie configuration issues, reverse proxy stripping auth headers, and space-aware access confusion after login.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Login & Authentication

**Purpose**: Identify why users cannot log into Kibana or are being rejected after login, and prescribe the fix.

## Use When
- Login page loops or redirects without completing
- SAML/OIDC/LDAP credentials not accepted
- Sessions expiring too quickly or immediately
- User logs in but sees empty UI or 403

## Do Not Use When
- Kibana not starting → kibana/startup-availability
- User logged in but missing features → kibana/authorization-spaces

## Inputs Needed
- Auth provider type (basic, SAML, OIDC, LDAP, Kerberos)
- Specific error message (assertion expired, redirect loop, cookie issue)
- Whether error is in Kibana log or browser (or both)
- Whether `kibana_system` user credentials are correct

## Diagnostic Logic

### Error Classification
| Pattern | Cause | First Check |
|---|---|---|
| `Kibana server is not ready yet` | `kibana_system` credentials wrong | Test credentials directly against ES |
| SAML redirect loop | `sp.entity_id` mismatch with IdP | Verify exact entity ID match |
| `assertion expired` | Clock skew > 2 min (ES ↔ IdP) | Sync NTP on all servers |
| `session expired` immediately | Wrong `encryptionKey` or `secureCookies` on HTTP | Check cookie settings |
| Login succeeds but empty UI | User has no role → no space access | Check role mapping |

### Kibana-to-Elasticsearch Auth
- Kibana uses `kibana_system` user (or service account token in 8.x) to connect to ES
- Wrong credentials → `Unable to retrieve version information` or all users fail to log in
- The `kibana_system` user must have the `kibana_system` built-in role

### SAML Issues
| Issue | Cause | Fix |
|---|---|---|
| Redirect loop | `sp.entity_id` mismatch | Match exactly what IdP expects |
| Assertion expired | Clock skew > 2 min | Sync NTP; extend `assertion_max_expiration` |
| ACS URL error | ACS not registered in IdP | Register `/api/security/saml/callback` in IdP |
| Role not assigned | Role attribute missing from assertion | Update IdP to include group attribute |

### Cookie / Session Issues
| Setting | Problem | Fix |
|---|---|---|
| `server.secureCookies: true` on HTTP | Login loop — secure cookies require HTTPS | Enable HTTPS or set `false` |
| Wrong `encryptionKey` | Sessions can't be decrypted after restart | Set consistent 32+ char key |
| Different keys across Kibana nodes | Sessions invalid across nodes | Same key on all nodes |

- In 8.x, sessions stored in `.kibana_sessions` index — sticky sessions NOT required

### OIDC Issues
- `client_id` / `client_secret` mismatch → token endpoint returns 401
- `redirect_uri` not registered in IdP → `redirect_uri_mismatch` error
- Token endpoint unreachable from Kibana server → timeout

### LDAP Issues
- LDAP auth config is on the **Elasticsearch** side, not Kibana
- Kibana forwards credentials to ES realms
- Diagnose LDAP connectivity at ES level (logstash-plain.log or elasticsearch.log)

### Reverse Proxy Auth Requirements
- Must NOT strip or modify `Authorization` header
- For SAML: must not intercept the SAML callback URL (`/api/security/saml/callback`)
- Must forward `X-Forwarded-For` and `X-Forwarded-Proto`

### Post-Login Access Confusion
- User in no space (other than default) → only sees default space
- User in space with no features enabled → empty navigation
- Check role's Kibana privileges per space

## Shared Skills
→ [authentication_checks](../../../../shared/authentication_checks.md) — auth error classification by realm type
→ [log_filtering](../../../../shared/log_filtering.md) — filter for authentication, session, SAML error patterns

## KCS Queries
`"kibana login failed authentication SAML"`, `"kibana SAML assertion expired clock skew"`, `"kibana session expired secure cookie HTTP"`, `"kibana OIDC redirect_uri mismatch"`

## Output
Report: auth provider type, error type (credentials/session/SAML/cookie), root cause, fix.
