#!/bin/bash
# triage_pipelines.sh - Identify failing ingest processors
# Expects: nodes_stats.json (from _nodes/stats)
FILE=$1

if [ ! -f "$FILE" ]; then
    echo "Usage: $0 <nodes_stats.json>"
    exit 1
fi

echo "--- Ingest Pipeline Failures ---"
jq -r '
  [.nodes | to_entries[] | .value.name as $node | .value.ingest.pipelines | to_entries[] | .key as $pipeline | .value.processors[] | to_entries[] | select(.value.stats.failed > 0) | 
  {node: $node, pipeline: $pipeline, processor: .key, failed: .value.stats.failed}] 
  | group_by(.pipeline + .processor) 
  | map({pipeline: .[0].pipeline, processor: .[0].processor, total_failed: (map(.failed) | add)}) 
  | sort_by(-.total_failed) 
  | .[] 
  | "Pipeline: \(.pipeline) | Processor: \(.processor) | Total Failed: \(.total_failed)"
' "$FILE" | column -t -s '|'
