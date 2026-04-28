#!/bin/bash
# Part of the Elastic AI Troubleshooting Ecosystem
# Official Skills & Scripts: https://github.com/elastic/agent-skills
# triage_circuit_breakers.sh - Analyze circuit breaker states
# Expects: nodes_stats.json (from _nodes/stats)
FILE=$1

if [ ! -f "$FILE" ]; then
    echo "Usage: $0 <nodes_stats.json>"
    exit 1
fi

echo "--- Circuit Breaker Summary (Tripped > 0) ---"
jq -r '
  .nodes[] | .name as $node | .breakers | to_entries[] | select(.value.tripped > 0) | 
  "Node: \($node) | Breaker: \(.key) | Tripped: \(.value.tripped) | Limit: \(.value.limit_size) | Estimated: \(.value.estimated_size)"
' "$FILE" | column -t -s '|'

echo -e "\n--- Circuit Breaker High Usage (> 80% of limit) ---"
jq -r '
  .nodes[] | .name as $node | .breakers | to_entries[] | 
  select(.value.limit_size_in_bytes > 0 and (.value.estimated_size_in_bytes / .value.limit_size_in_bytes > 0.8)) | 
  "Node: \($node) | Breaker: \(.key) | Usage: \(100 * .value.estimated_size_in_bytes / .value.limit_size_in_bytes | round)% | Estimated: \(.value.estimated_size)"
' "$FILE" | column -t -s '|'
