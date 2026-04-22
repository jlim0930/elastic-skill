#!/bin/bash
# triage_logs.sh - Quick log analysis for error distribution
FILE=$1
SEARCH_TERM=${2:-"ERROR|WARN|Exception"}

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

echo "--- Error/Warning Distribution ---"
grep -E "$SEARCH_TERM" "$FILE" | awk -F' ' '{for(i=1;i<=NF;i++) if($i ~ /Exception|Error/) {print $i; next}} {print "Generic Error"}' | sort | uniq -c | sort -nr | head -n 10

echo -e "\n--- Latest 5 Critical Events ---"
grep -E "$SEARCH_TERM" "$FILE" | tail -n 5
