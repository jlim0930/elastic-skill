# ECH Heuristics

- **JVM Heap**: Alerts at >85% for sustained periods. Critical at >95%.
- **Disk Usage**: Low Watermark (85%), High Watermark (90%), Flood Stage (95%).
- **Shard Sizing**: Recommend 10GB-50GB per shard. Max shards per node = 20 * GB Heap.
- **Plan Timeouts**: Plans exceeding 4 hours usually indicate data migration bottlenecks or hung tasks.
