# Ingest and Pipeline Troubleshooting

## Ingest Pipelines
- **Common Issues**: Script errors (Painless), missing fields, processor failures, or unexpected data types.
- **Troubleshooting Steps**:
  1. Use the **Simulate Pipeline API** to test documents against the pipeline.
  2. Check for `on_failure` handlers and `_ingest.on_failure_message`.
  3. Inspect `_ingest.timestamp` to verify when documents entered the pipeline.
- **In-Depth Methods**:
  1. Profile pipelines using the `verbose` flag in the Simulate API to see every transformation step.
  2. Monitor `nodes_stats` for ingest performance (count, time, current, failed).

## Elastic Agent and Beats
- **Common Issues**: Connectivity (TLS/Cert), permission errors, or backpressure from Elasticsearch.
- **Troubleshooting Steps**:
  1. Check `agent list` or `beat status` on the host.
  2. Inspect local logs (e.g., `/opt/Elastic/Agent/data/elastic-agent-*/logs/`).
  3. Verify `outputs.elasticsearch.hosts` and TLS config.
- **In-Depth Methods**:
  1. Enable debug logging and check for "failed to publish events" or "circuit breaker" errors.
  2. Use `tcpdump` or `curl -v` from the agent host to verify network path.

## OpenTelemetry (OTel)
- **Common Issues**: Incorrect exporter configuration, span drop due to rate limiting, or schema mismatches.
- **Troubleshooting Steps**:
  1. Check the OTel Collector logs for "Exporting failed" errors.
  2. Verify the OTLP endpoint in the Elastic APM/Elasticsearch integration.
- **In-Depth Methods**:
  1. Use the `logging` or `debug` exporter in the OTel Collector to see raw spans before they are sent to Elastic.
  2. Correlate OTel logs with APM traces in Kibana to find missing segments.
