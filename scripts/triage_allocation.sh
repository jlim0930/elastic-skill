#!/bin/bash
# triage_allocation.sh - Summarize shard allocation status and common reasons
FILE=$1 # Expecting a JSON file with _cat/shards or _cluster/allocation/explain output

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

echo "--- Unassigned Shard Summary ---"
grep "UNASSIGNED" "$FILE" | awk '{print $1, $2}' | sort | uniq -c

echo -e "\n--- Top Allocation Decider Messages ---"
grep -oE "node_left|target_node_not_found|disk_threshold|throttled|awaiting_info|no_valid_shard_copy" "$FILE" | sort | uniq -c | sort -nr
