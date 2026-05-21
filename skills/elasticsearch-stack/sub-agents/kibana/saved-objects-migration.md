---
name: kb-saved-objects-migration
description: Diagnoses Kibana saved object import/export failures including unknown_type and missing_references errors, upgrade migration stuck or partially complete, corrupt saved objects, cross-version compatibility issues, .kibana index read-only block, and space copy/share license restrictions.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# KB — Saved Objects & Migration

**Purpose**: Identify why saved object import/export fails or Kibana migration is stuck, and prescribe the fix.

## Use When
- Saved object import fails with `unknown_type` or `missing_references`
- Kibana migration stuck at REINDEX or CLONE stage during upgrade
- Saved objects from one space not accessible in another
- `.kibana` index read-only block preventing migration

## Do Not Use When
- Kibana not starting at all → kibana/startup-availability
- License or feature restriction → check `kibana/authorization-spaces`

## Inputs Needed
- Migration failure stage (from Kibana log during upgrade)
- Import error type (`unknown_type`, `missing_references`, `conflict`)
- `.kibana` index health and any blocks
- Whether cross-space sharing is needed (license level)

## Diagnostic Logic

### Migration Stage Classification
```
INIT → WAIT_FOR_YELLOW_SOURCE → REINDEX → CLONE_TEMP_TO_TARGET → UPDATE_TARGET_MAPPINGS → UPDATE_ALIASES → DONE
```

| Failure Stage | Cause | Fix |
|---|---|---|
| `WAIT_FOR_YELLOW_SOURCE` | `.kibana` index is RED | Fix ES shard allocation for `.kibana` |
| `REINDEX` | ES reindex failed; cluster under pressure | Fix ES cluster health; restart Kibana to retry |
| `CLONE_TEMP_TO_TARGET` | Target index naming conflict | Delete `.kibana_<version>_001`; restart Kibana |
| `UPDATE_TARGET_MAPPINGS` | Read-only block or disk watermark | Clear block after freeing disk |
| `FATAL: Unable to complete migration` | Unrecoverable state | Manual index deletion + Kibana restart |

### .kibana Index Blocks
- `read_only_allow_delete: true` → disk flood-stage triggered → free disk, then clear the block
- `RED` health → primary shard not allocated → fix ES cluster allocation first
- Clear block after resolving root cause (freeing disk or fixing shard allocation)

### Import Error Classification
| Error | Cause | Fix |
|---|---|---|
| `unknown_type` | Object type removed in target Kibana version | Cannot import; use older Kibana or re-create manually |
| `missing_references` | Referenced data view doesn't exist in target | Create data view first; then re-import |
| `conflict` | Object ID already exists | Add `?overwrite=true` to import request |
| `unsupported_type` | Encrypted saved object (connector/rule) with different key | Ensure same `encryptedSavedObjects.encryptionKey` |

### Cross-Version Import Rules
- Import from older version to newer version = auto-migrated on import (generally safe)
- Import from newer to older version = rejected (downgrade not supported)
- Always export from older Kibana, import to newer Kibana

### Corrupt Saved Objects
- Objects without a `type` field cause errors in Kibana
- Find corrupt objects by querying `.kibana` for documents missing the `type` field
- Find orphaned references pointing to deleted objects
- Delete corrupt objects directly from `.kibana` index by document ID

### Space Copy / Share
| Feature | Basic | Gold | Platinum/Enterprise |
|---|---|---|---|
| Copy object to another space | Yes | Yes | Yes |
| Share object across spaces (live) | No | No | Yes |

- `"cannot share across spaces"` = Platinum+ license required
- Export from one space and import to another = available on all licenses (not live sharing)

### Export Best Practices
- Always use `includeReferencesDeep: true` to capture all dependencies (data views, lens layers)
- Verify export completeness: count objects by type in the NDJSON file
- Export before any migration or significant upgrade

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for migration stage keywords, FATAL, REINDEX patterns
→ [error_pattern_matching](../../../../shared/error_pattern_matching.md) — classify import errors before routing

## KCS Queries
`"kibana saved object import failed unknown_type missing_references"`, `"kibana migration stuck REINDEX upgrade"`, `"kibana .kibana index read-only block"`, `"kibana space copy share license restriction"`

## Output
Report: migration stage or import error type, `.kibana` health, root cause, fix steps.
