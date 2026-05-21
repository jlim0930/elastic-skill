---
name: es-machine-learning
description: Diagnoses Elasticsearch ML anomaly detection job failures, datafeed not starting, model memory limit problems, anomaly results not appearing, forecast failures, ML node capacity constraints, trained model deployment issues, and data frame analytics problems.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ES — Machine Learning

**Purpose**: Identify why an ML job, datafeed, or trained model is not working and prescribe the fix.

## Use When
- Anomaly detection job in `failed` or stuck `opening` state
- Datafeed in `stopped` state unexpectedly
- Model memory `hard_limit` reached
- Trained model not deployed or inference failing
- Data frame analytics stuck in a phase

## Do Not Use When
- ML Kibana UI issues (not backend) → kibana/machine-learning-ui
- Cluster health blocking ML → es/cluster-health first

## Inputs Needed
- Job ID and current state (`failed`, `opening`, `closed`)
- `failure_reason` from job stats
- ML node count and memory allocation
- Whether issue is anomaly detection, DFA, or trained model

## Diagnostic Logic

### Job State Classification
| State | Action |
|---|---|
| `opened` | Running — check datafeed and results |
| `opening` stuck > 5 min | Check ML node capacity — no memory to open job |
| `closed` | Manually stopped — open to resume |
| `failed` | Read `failure_reason` field — fatal error |

### Datafeed Issues
- `stopped` state with `assignment_explanation` → reason for not starting
- Preview datafeed to verify query works: `_ml/datafeeds/<id>/_preview`
- `stopped` unexpectedly → check for search errors against source index
- Source index deleted or access denied → datafeed cannot query data

### Model Memory
| Status | Meaning | Action |
|---|---|---|
| `ok` | Within limit | Normal |
| `soft_limit` | Approaching limit; some pruning | Consider increasing limit |
| `hard_limit` | Hit limit; results incomplete | Increase limit (close job first) |

- Job memory limit cannot exceed `_ml/info` cluster max — job won't open if it does
- Close job before changing `model_memory_limit`

### ML Node Capacity
- No nodes with `ml` role → jobs cannot open
- All ML node memory allocated → new jobs queued waiting for capacity
- Memory check: compare job memory limits against available ML memory per node
- Large NLP trained models (BERT-size): require 4+ GB per allocation on `ml` nodes

### Delayed Data
- `delayed_data_count` > 0 = events arriving after datafeed window closed
- Fix: increase `query_delay` (how far back datafeed looks) to 120s or more
- Or increase `frequency` (how often datafeed runs) to catch late data sooner
- High `empty_bucket_count` = data is sparse for bucket span → increase bucket span

### Anomaly Results Missing
- Check if `.ml-anomalies-<job_id>` index exists and has documents
- `processed_record_count` = 0 → datafeed not feeding data to job
- High `empty_bucket_count` → bucket span too small for data frequency
- Anomaly threshold in UI filter may be hiding low-score results — lower threshold

### Forecasting Requirements
- Job must have been running for at least 1 week for reliable forecasts
- `memory_status` must not be `hard_limit`
- `insufficient data for forecasting` → not enough history — let job run longer

### Trained Model Deployment
- Model not in `started` state → inference requests fail
- Check `deployment_stats.reason` for failure message
- Start deployment with `_ml/trained_models/<id>/deployment/_start`
- Requires `ml` nodes with sufficient free memory
- Deployment fails if total model allocations exceed available ML memory

### Data Frame Analytics Phases
| Phase | Stuck Cause |
|---|---|
| `reindexing` | Source index access error |
| `loading_data` | Source index health or query issue |
| `analyzing` | ML node memory exhausted |
| `writing_results` | Destination index write blocked |

- DFA is memory-intensive during `analyzing` — check ML node free memory
- Check `failure_reason` in DFA stats for specific error

## Shared Skills
→ [log_filtering](../../../../shared/log_filtering.md) — filter for ML exceptions and job state transitions

## KCS Queries
`"ML job failed to open elasticsearch memory"`, `"datafeed stopped assignment_explanation"`, `"model memory hard_limit anomaly detection"`, `"trained model deployment failed elasticsearch"`

## Output
Report: job/model ID, state, failure reason, ML node capacity status, specific fix (memory increase / node addition / datafeed query fix).
