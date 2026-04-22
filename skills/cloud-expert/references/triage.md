# ECH Triage Sequence

1. **Deployment Health**: Check Console signals (Healthy, Maintenance, Failing).
2. **Plan History**: Analyze recent plan changes. Identify 'Step' where failure occurred.
3. **Elasticsearch Health**: Review `_cluster/health`, `_nodes/stats`, and `_cat/shards`.
4. **GC & Heap**: Correlate GC frequency with Heap usage and platform-level CPU signals.
5. **Autoscaling**: Verify if autoscaling events (up or down) are triggered or blocked.
