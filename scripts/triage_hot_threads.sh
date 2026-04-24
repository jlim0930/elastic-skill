#!/bin/bash
# triage_hot_threads.sh - Condenses verbose Elasticsearch hot_threads output
FILE=$1

if [ ! -f "$FILE" ]; then
    echo "File not found: $FILE"
    exit 1
fi

echo "--- Top CPU Threads Summary ---"
# Extracts lines with the thread name/cpu and the first java class it's stuck in
awk '
    /^[ \t]*[0-9.]+% .* cpu usage/ {
        thread = $0
        gsub(/^[ \t]+|[ \t]+$/, "", thread)
        found_trace = 0
    }
    /^[ \t]+[a-zA-Z0-9_.]+\// {
        if (!found_trace) {
            trace = $0
            gsub(/^[ \t]+|[ \t]+$/, "", trace)
            print "THREAD: " thread "\n  -> " trace "\n"
            found_trace = 1
        }
    }
' "$FILE" | head -n 40
