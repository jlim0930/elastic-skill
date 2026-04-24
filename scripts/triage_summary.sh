#!/bin/bash
# triage_summary.sh - High-level cluster overview
# Expects a directory containing standard diagnostic JSON files

DIR=${1:-.}

if [ ! -d "$DIR" ]; then
    echo "Directory not found: $DIR"
    exit 1
fi

echo "================================================================================"
echo "CLUSTER HEALTH SUMMARY"
echo "================================================================================"

if [ -f "$DIR/version.json" ]; then
    echo -n "Elasticsearch Version: "
    jq -r '.version.number' "$DIR/version.json" 2>/dev/null || jq -r '.data.version.number' "$DIR/version.json" 2>/dev/null
fi

if [ -f "$DIR/health.json" ]; then
    echo -n "Cluster Status: "
    jq -r '.status' "$DIR/health.json"
    echo -n "Nodes: Total: "
    jq -r '.number_of_nodes' "$DIR/health.json"
    echo -n "Shards: Unassigned: "
    jq -r '.unassigned_shards' "$DIR/health.json"
fi

if [ -f "$DIR/nodes.json" ]; then
    echo -e "\n--- Node Roles ---"
    jq -r '.nodes[] | .roles[]' "$DIR/nodes.json" | sort | uniq -c
fi

if [ -f "$DIR/nodes_stats.json" ]; then
    echo -e "\n--- High Resource Usage ---"
    jq -r '.nodes[] | select(.jvm.mem.heap_used_percent > 85) | "High Heap: \(.name) (\(.jvm.mem.heap_used_percent)%)"' "$DIR/nodes_stats.json"
    jq -r '.nodes[] | select(.os.cpu.percent > 90) | "High CPU: \(.name) (\(.os.cpu.percent)%)"' "$DIR/nodes_stats.json"
    jq -r '.nodes[] | select(.fs.total.available_in_bytes / .fs.total.total_in_bytes < 0.1) | "Low Disk: \(.name) (<\(100 * .fs.total.available_in_bytes / .fs.total.total_in_bytes | round)%)"' "$DIR/nodes_stats.json"
fi

echo "================================================================================"
