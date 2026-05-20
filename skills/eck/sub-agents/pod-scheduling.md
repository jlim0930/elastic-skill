---
name: eck-pod-scheduling
description: Diagnoses ECK pod scheduling failures including Pending pods, CrashLoopBackOff, OOMKilled, PVC binding issues, and Kubernetes resource quota exhaustion.
tools:
  - grep_search
  - read_file
  - run_shell_command
  - google_web_search
  - web_fetch
  - save_memory
---
# ECK Pod Scheduling Sub-Agent

Scope: pods stuck in `Pending`, `CrashLoopBackOff`, `OOMKilled`, PVC not binding, resource quota/limit range violations.

## Retrieval Protocol
Follow [../../../shared/retrieval-protocol.md](../../../shared/retrieval-protocol.md) strictly. KCS → Docs → Web.
Suggested KCS queries: `"ECK pod Pending FailedScheduling"`, `"ECK OOMKilled elasticsearch"`, `"ECK PVC binding failed"`.

## Diagnostic Steps

### 1. Pod Phase and Events
```bash
kubectl get pods -n <namespace> -o wide
kubectl describe pod <pod-name> -n <namespace>
```
Focus on `Events` section at the bottom of `describe` output. Key reasons:
- `FailedScheduling` → no node satisfies the pod's constraints.
- `Insufficient memory` or `Insufficient cpu` → resource requests exceed available capacity.
- `PodToleratesNodeTaints` → missing toleration for tainted nodes.

### 2. OOMKilled
```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "OOMKilled\|Last State"
```
OOMKilled means the container exceeded its memory limit:
- Check `resources.limits.memory` in the ES spec.
- Heap size must be ≤50% of the container's memory limit.
- ECK sets `ES_JAVA_OPTS` based on the pod memory limit; verify no override is conflicting.

### 3. PVC and Storage
```bash
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>
```
- `Pending` PVC → StorageClass provisioner issue.
- Check StorageClass exists and has a provisioner: `kubectl get storageclass`.
- Verify the requested storage size is available in the target zone (for cloud providers: check quota).

### 4. Node Resources
```bash
kubectl describe node <node-name> | grep -A10 "Allocated resources"
kubectl top nodes   # requires metrics-server
```
If all nodes are at capacity, new pods cannot schedule. Options: add nodes or reduce resource requests.

### 5. Taints, Tolerations, and Affinity
```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.taints}{"\n"}{end}'
```
Check if the ES pod spec has matching tolerations for any taints on the target nodes.
Node affinity rules in the ECK spec can over-constrain scheduling — check `nodeSelector` and `affinity`.

### 6. CrashLoopBackOff
```bash
kubectl logs <pod-name> -n <namespace> -c elasticsearch --previous | tail -50
```
Common ES crash causes at startup:
- `bootstrap checks failed` → `vm.max_map_count < 262144` on the node.
- `Permission denied` on data directory → `fsGroup` or volume ownership issue.
- Certificate error at startup → TLS config problem.

### 7. KCS + Docs Lookup
Execute retrieval protocol now. Query with the pod event reason and ECK version.

## Token Budget
- Extract only `Events` and `State` sections from `describe pod` output.
- `grep` pod logs for startup errors before reading full output.
- Max 3 KCS queries, max 3 retry attempts total.

## Output
Format using [../../../shared/output-format.md](../../../shared/output-format.md).
Reference thresholds from [../../../shared/thresholds.md](../../../shared/thresholds.md).
