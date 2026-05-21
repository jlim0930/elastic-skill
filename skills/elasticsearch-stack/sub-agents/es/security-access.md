---
name: es-security-access
description: Diagnoses Elasticsearch authentication failures across native/LDAP/AD/SAML/OIDC realms, role mapping issues, API key lifecycle problems, document-level and field-level security behavior, and built-in user management.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Security & Access Control

**Purpose**: Identify why authentication is failing or why a user lacks expected permissions, and prescribe the fix.

## Use When
- 401 Unauthorized on API requests
- 403 Forbidden despite expected role
- SAML/OIDC/LDAP login not working
- API key rejected or expired

## Do Not Use When
- TLS handshake fails before auth → es/tls-certificates
- Audit logging setup (not troubleshooting) → use docs

## Inputs Needed
- HTTP status code (401 vs 403 vs redirect loop)
- Auth method in use (native / LDAP / SAML / OIDC / API key)
- Exact error message from ES logs or API response
- Username and roles expected vs assigned

## Diagnostic Logic

### Error Classification
| Status | Meaning | First Check |
|---|---|---|
| 401 | Authentication failed | Wrong credentials; realm order; realm connectivity |
| 403 | Auth succeeded, permission denied | Role missing or role mapping not matching |
| Redirect loop | SSO misconfiguration | ACS URL or `sp.entity_id` mismatch |
| `missing_secrets` | Keystore value not set | Check `elasticsearch-keystore list` |

### Realm Order
- Realm `order` field: lower number = higher priority (tried first)
- Native realm should be order 0 for admin/local fallback
- External realms (LDAP, SAML) at higher order values
- If LDAP is order 0 and LDAP is down → all native users also fail to log in

### Auth Error by Realm
| Error | Realm | Cause |
|---|---|---|
| `failed to authenticate user` | native/file | Wrong password or user doesn't exist |
| `LDAP connection refused` | ldap/ad | LDAP server unreachable |
| `SAML assertion expired` | saml | Clock skew > 2 min between ES and IdP |
| `Could not validate OIDC token` | oidc | Token expired or wrong `client_id` |

### Role Mapping Check
- Role mapping rules not matching → user gets no roles → 403 on all API calls
- Simulate whether a user's attributes match: use `_security/role_mapping/<name>/_simulate_using`
- Check effective roles assigned to a user via `_security/_authenticate` (as that user)
- Confirm privileges with `_security/user/<name>/_has_privileges`

### API Key Format
- HTTP Authorization header: `ApiKey <base64(id:api_key)>`
- Logstash elasticsearch output config: `id:api_key` (colon-separated, NOT base64)
- Mixing the two formats → persistent 401
- Invalidated or expired keys return 401 — check key status via `_security/api_key?id=<id>`

### SAML Issues
| Symptom | Cause | Fix |
|---|---|---|
| Assertion expired | Clock skew > 2 min | Sync NTP; extend `assertion_max_expiration` |
| Wrong SP entity ID | `sp.entity_id` mismatch | Match exactly what IdP expects |
| Role attribute missing | IdP not sending role attribute | Update IdP attribute mapping |
| Redirect loop | ACS URL mismatch | Verify `sp.acs` URL in both IdP and ES config |

### LDAP / AD Issues
- Wrong `bind_dn` or `bind_password` → authentication fails for all users
- LDAPS (port 636) requires `ssl.certificate_authorities` in realm config
- Group search `base_dn` too narrow → user groups not found → no roles assigned
- Test LDAP connectivity independently from ES to isolate network vs config

### DLS / FLS Behavior
- DLS (Document Level Security): query filter applied at search time per user
- FLS (Field Level Security): `grant` list OR `except` list — cannot combine both in one role
- Test effective permissions: search as the affected user; compare results to admin search
- DLS/FLS applied per role — if user has multiple roles, most permissive wins

## Shared Skills
→ [authentication_checks](../../../../shared/authentication_checks.md) — auth error classification, realm diagnosis steps
→ [log_filtering](../../../../shared/log_filtering.md) — filter for authentication_failed, access_denied

## KCS Queries
`"elasticsearch authentication failed realm"`, `"role mapping LDAP active directory elasticsearch"`, `"API key expired unauthorized elasticsearch"`, `"SAML assertion expired clock skew"`

## Output
Report: auth method, error type (401/403/loop), realm failing and why, role mapping match status, specific fix.
