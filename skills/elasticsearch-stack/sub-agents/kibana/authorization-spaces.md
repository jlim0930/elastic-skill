---
name: kb-authorization-spaces
description: Diagnoses Kibana missing features in UI due to role restrictions, space permissions not behaving as expected, feature controls confusion, saved object access denied across spaces, multi-tenant isolation questions, and role mapping from external auth providers to Kibana privileges.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Authorization & Spaces

**Purpose**: Identify why a user has no access or incorrect access in Kibana spaces, and prescribe the role or mapping fix.

## Use When
- Feature hidden in Kibana UI (nav item missing)
- 403 error on Kibana API despite being logged in
- Saved object visible in one space but not another
- SAML/LDAP user has no space access after login

## Do Not Use When
- Login fails (not access) → kibana/login-authentication
- ES-level data access denied (not Kibana) → es/security-access

## Inputs Needed
- Affected user's role name(s)
- Space ID(s) user should have access to
- Feature that is hidden or returning 403
- Auth provider type (native vs SAML/LDAP)

## Diagnostic Logic

### Kibana Privilege Structure
- `base: ["all"]` → full access to all features in that space
- `base: ["read"]` → read-only on all features in that space
- `feature.<feature_id>: ["all"]` → feature-specific override
- Space `["*"]` in role → applies to all spaces including future ones

### Feature Controls vs ES Permissions
- Feature controls hide/show Kibana apps within a space — navigation-level only
- Disabled features in space settings → hidden in nav; API access may still work
- User sees feature in nav but gets 403 on API → feature shown (control OK), but ES role lacks index privileges
- These are two different layers: Kibana space features ≠ ES index privileges

### Space Membership
- User only sees spaces they have been assigned to via their role's Kibana privileges
- User not assigned to any space (other than default) → only sees default space
- User assigned to space with no features enabled → empty navigation

### Saved Object Access
- Saved objects (dashboards, visualizations, data views) are space-scoped
- Objects created in Space A are NOT visible in Space B unless explicitly shared
- Attempting to reference object from another space → 403
- Object sharing across spaces requires Platinum+ license

### Role Mapping from External Auth (SAML/LDAP)
- LDAP/SAML users get ES roles via role mapping; ES roles grant Kibana privileges
- Missing role mapping → user authenticates but has no Kibana privileges → empty space or error
- Test role mapping: use `_security/role_mapping/<name>/_simulate_using` with user attributes
- No space access after SSO login → always check role mapping first

### Multi-Tenant Isolation
- Kibana Spaces provide UI and saved-object isolation — NOT Elasticsearch data isolation
- For true data isolation: use separate ES indices per tenant + DLS/FLS roles per tenant
- Map auth group/claim to tenant-specific ES role that restricts to tenant-specific indices

### Common Troubleshooting Path
1. Confirm user's assigned roles and their Kibana privileges per space
2. Confirm space feature controls (are features disabled in space settings?)
3. If external auth: verify role mapping is matching the user's attributes
4. For 403 on data: check ES role's index privileges separately from Kibana privileges

## Shared Skills
→ [authentication_checks](../../../../shared/authentication_checks.md) — role mapping simulation and privilege checks
→ [log_filtering](../../../../shared/log_filtering.md) — filter for access_denied, 403, saved object errors

## KCS Queries
`"kibana role missing feature UI space"`, `"kibana space permission denied saved object"`, `"kibana role mapping SAML LDAP no access"`, `"kibana multi-tenant space isolation data"`

## Output
Report: affected user, space, feature or object, missing privilege layer (Kibana space/feature or ES index), fix.
