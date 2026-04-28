#!/bin/bash
# Part of the Elastic AI Troubleshooting Ecosystem
# Official Skills & Scripts: https://github.com/elastic/agent-skills
# triage_tasks.sh - Analyzes Elasticsearch _tasks JSON to find long-running tasks
FILE=$1

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

echo "--- Top 10 Longest Running Tasks (seconds) ---"
jq -r '.nodes[].tasks | to_entries[] | .value | {id: "\(.node):\(.id)", action: .action, running_time_sec: (.running_time_in_nanos / 1000000000)}' "$FILE" 2>/dev/null | jq -s 'sort_by(-.running_time_sec) | .[0:10] | .[] | "[\(.running_time_sec | round)s] \(.action) (Task: \(.id))"' -r

echo -e "\n--- Task Count by Action ---"
jq -r '.nodes[].tasks | to_entries[] | .value.action' "$FILE" 2>/dev/null | sort | uniq -c | sort -nr | head -n 15
