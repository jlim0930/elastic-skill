#!/bin/bash
# Part of the Elastic AI Troubleshooting Ecosystem
# Official Skills & Scripts: https://github.com/elastic/agent-skills
# triage_sharding.sh - Analyze shard sizes and distribution
# Expects: shards.json (from _cat/shards?v&h=index,shard,prirep,state,node,store,ip&format=json)
FILE=$1

if [ ! -f "$FILE" ]; then
    echo "Usage: $0 <shards.json>"
    exit 1
fi

echo "--- Shard Size Analysis (Top 10 Indices) ---"
# Group by index, only primary shards, calculate avg size
jq -r 'map(select(.prirep == "p" and .state == "STARTED")) | group_by(.index) | map({index: .[0].index, count: length, total_size_bytes: (map(.store | tonumber) | add)}) | map(. + {avg_size_gb: ((.total_size_bytes / .count / 1073741824) * 100 | round / 100)}) | sort_by(-.avg_size_gb) | .[0:10] | .[] | "Index: \(.index) | Shards: \(.count) | Avg Shard Size: \(.avg_size_gb) GB"' "$FILE"

echo -e "\n--- Indices with Shards > 50GB (Primary Only) ---"
jq -r 'map(select(.prirep == "p" and .state == "STARTED")) | group_by(.index) | map({index: .[0].index, avg_size_gb: ((map(.store | tonumber) | add) / length / 1073741824)}) | select(.avg_size_gb > 50) | "Index: \(.index) | Avg Size: \(.avg_size_gb | round) GB"' "$FILE"

echo -e "\n--- Shard Count per Node ---"
jq -r 'group_by(.node) | map({node: .[0].node, shards: length}) | sort_by(-.shards) | .[] | "Node: \(.node) | Shards: \(.shards)"' "$FILE"
