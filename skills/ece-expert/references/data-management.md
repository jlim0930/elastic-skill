# Data Management: ILM, Snapshots, CCS/CCR

## Index Lifecycle Management (ILM)
- **Common Issues**: Index stuck in a phase, missing template/policy, or resource constraints (e.g., no room on Warm tier).
- **Troubleshooting Steps**:
  1. Run `GET <index>/_ilm/explain` to see the current step and any errors.
  2. Check `GET _ilm/status` to ensure the ILM service is running.
- **In-Depth Methods**:
  1. Identify "Illegal Argument" errors in the explain output (often due to missing aliases).
  2. Check for "Shrink" or "Force Merge" failures caused by blocked allocation.

## Snapshots and SLM
- **Common Issues**: Repository accessibility, S3/GCS/Azure permission issues, or partial snapshots.
- **Troubleshooting Steps**:
  1. Run `GET _snapshot/<repo>/_all` to check status.
  2. Verify repository with `POST _snapshot/<repo>/_verify`.
- **In-Depth Methods**:
  1. Inspect the "failures" section of the snapshot metadata for specific file-level errors.
  2. Check `nodes_stats` for snapshot-related thread pool rejections.

## CCS (Cross-Cluster Search) & CCR (Cross-Cluster Replication)
- **Common Issues**: Remote cluster connectivity, version mismatch, or certificate trust issues.
- **Troubleshooting Steps**:
  1. Check remote cluster status with `GET _remote/info`.
  2. For CCR, check `GET <follower_index>/_ccr/stats`.
- **In-Depth Methods**:
  1. Debug TLS handshake failures using `openssl s_client` between cluster nodes.
  2. Monitor "Leader" vs "Follower" lag in CCR to identify network bottlenecks.

## Transforms
- **Common Issues**: Resource exhaustion, circuit breakers, or incorrect aggregations.
- **Troubleshooting Steps**:
  1. Check `GET _transform/<id>/_stats`.
  2. Look for "failed" status and the "reason" field.
- **In-Depth Methods**:
  1. Inspect search rejections during the transform's extract phase.
  2. Tune `max_page_search_size` if transform is timing out or hitting memory limits.
