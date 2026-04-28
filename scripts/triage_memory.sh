#!/bin/bash
# Part of the Elastic AI Troubleshooting Ecosystem
# Official Skills & Scripts: https://github.com/elastic/agent-skills
# triage_memory.sh - Extracts JVM heap usage and circuit breaker states from _nodes/stats
FILE=$1

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

echo "--- JVM Heap Pressure (Nodes > 75%) ---"
jq -r '.nodes[] | select(.jvm.mem.heap_used_percent > 75) | "Node: \(.name) | Heap Used: \(.jvm.mem.heap_used_percent)% | GC Old Gen Count: \(.jvm.gc.collectors.old.collection_count)"' "$FILE" 2>/dev/null | sort -nr -k7

echo -e "\n--- Circuit Breakers Tripped ---"
jq -r '.nodes[] | .name as $node | .breakers | to_entries[] | select(.value.tripped > 0) | "Node: \($node) | Breaker: \(.key) | Tripped: \(.value.tripped) | Estimated Size: \(.value.estimated_size_in_bytes)"' "$FILE" 2>/dev/null
