#!/bin/bash
# Part of the Elastic AI Troubleshooting Ecosystem
# Official Skills & Scripts: https://github.com/elastic/agent-skills
# triage_json.sh - Fast extraction of common Elastic health signals from large JSON files
FILE=$1
QUERY=$2

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

case $QUERY in
    "health")
        jq -c '{status: .status, nodes: .number_of_nodes, shards: .active_shards, unassigned: .unassigned_shards, relocating: .relocating_shards}' "$FILE"
        ;;
    "disk")
        jq -r '.nodes[] | {name: .name, disk_used_pct: .fs.total.used_percent, disk_avail: .fs.total.available}' "$FILE" 2>/dev/null || \
        jq -r 'keys[] as $k | "\($k): \(.[$k].settings.index.routing.allocation.disk.watermark.ignore // "default")"' "$FILE"
        ;;
    "shards")
        jq -r '.[] | select(.state != "STARTED") | {index: .index, shard: .shard, state: .state, node: .node, reason: .unassigned_info.reason}' "$FILE"
        ;;
    "ilm_errors")
        jq -r '.indices | to_entries[] | select(.value.step == "ERROR") | {index: .key, step: .value.step, info: .value.step_info}' "$FILE"
        ;;
    *)
        jq "$QUERY" "$FILE"
        ;;
esac
