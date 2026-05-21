# Authentication Checks

**Purpose**: Structured workflow to isolate auth failures across Elasticsearch, Kibana, and connected components.

## Step 1 — Identify the Auth Error
| Error | Category |
|---|---|
| `401 Unauthorized` | Wrong credentials or expired token |
| `403 Forbidden` | Auth succeeded but insufficient privilege |
| `authentication_exception` | Realm misconfiguration or token invalid |
| Login loop (Kibana) | Cookie / session issue, not auth failure |
| `is_missing_secrets: true` (connector) | Encryption key changed after connector creation |

## Step 2 — Identify the Auth Method
Check what auth providers are configured:
- Basic (username/password)
- API key
- SAML / OIDC
- LDAP / Active Directory
- PKI / client certificate
- Service account token (8.x)

Each method has different failure patterns.

## Step 3 — Check Credentials Directly
- Test the credential in isolation (not via Kibana or Logstash — directly to ES)
- Confirm the user exists and has the expected role
- Confirm the role has the expected index/cluster privileges

## Step 4 — Role and Privilege Check
- Does the role grant access to the required index pattern?
- Does the role grant the required cluster privileges?
- Is DLS/FLS filtering the data unintentionally?
- Is the role assigned to the correct user or role mapping?

## Step 5 — External Auth Providers (SAML/OIDC/LDAP)
SAML issues:
- `sp.entity_id` mismatch with IdP
- ACS URL not registered in IdP
- Clock skew > 2 min → assertion expired
- Role attribute not included in assertion

OIDC issues:
- `client_id` / `client_secret` mismatch
- `redirect_uri` not registered in IdP
- Token endpoint unreachable from server

LDAP issues:
- Config is on the ES side, not Kibana
- Test bind DN and base DN against the LDAP server directly
- Check `group_search` and `role_mapping` configuration

## Step 6 — API Key Format Check
- Logstash: API key format is `id:api_key` (colon-separated), NOT base64 encoded
- Kibana/ES API: use `Authorization: ApiKey <base64(id:api_key)>` header
- Mixing these up = 401 errors

## Common Fixes
| Scenario | Fix |
|---|---|
| Kibana `kibana_system` user wrong password | Reset password; update kibana.yml |
| SAML redirect loop | Fix `sp.entity_id` and ACS URL |
| Connector missing secrets | Re-enter credentials in Stack Management > Connectors |
| LDAP user no Kibana features | Check role_mapping links LDAP group to ES role with Kibana privileges |
| DLS hiding data | Confirm with admin user to compare doc counts |
