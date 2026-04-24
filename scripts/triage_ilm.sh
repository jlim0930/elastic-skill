#!/bin/bash
# triage_ilm.sh - Summarize ILM status and policies
# Expects: ilm_status.json and ilm_policies.json
STATUS_FILE=$1
POLICIES_FILE=$2

if [ ! -f "$STATUS_FILE" ] || [ ! -f "$POLICIES_FILE" ]; then
    echo "Usage: $0 <ilm_status.json> <ilm_policies.json>"
    exit 1
fi

echo "--- ILM Status ---"
jq -r '.operation_mode' "$STATUS_FILE"

echo -e "\n--- ILM Policies Summary ---"
jq -r 'to_entries[] | "Policy: \(.key) | Version: \(.value.version) | Indices: \(.value.in_use_by.indices | length) | Phases: \(.value.policy.phases | keys | join(", "))"' "$POLICIES_FILE" | column -t -s '|'
