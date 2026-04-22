# Advanced Features: ML, APM, Observability, Security

## Machine Learning (ML)
- **Common Issues**: Job memory limits (model memory limit), data sparsity, or allocator failures.
- **Troubleshooting Steps**:
  1. Check job status with `GET _ml/anomaly_detectors/<job_id>/_stats`.
  2. Look for "hard_limit" or "soft_limit" messages in the `model_bytes_exceeded` field.
- **In-Depth Methods**:
  1. Inspect the ML specialized thread pools and native process logs on ML nodes.
  2. Validate data feed performance using `GET _ml/datafeeds/<id>/_stats`.

## APM and RUM
- **Common Issues**: APM Server auth/secret token issues, ingest backpressure, or RUM source map mismatches.
- **Troubleshooting Steps**:
  1. Verify APM Server connectivity to Elasticsearch.
  2. Check APM Server logs for "Queue is full" or "Request body too large".
- **In-Depth Methods**:
  1. Correlate APM traces with Elasticsearch `slowlog` to find database-level bottlenecks.
  2. Inspect the `apm-*` index templates to ensure correct mapping of custom fields.

## Observability Correlation
- **Methods**:
  1. Use **Trace ID** to pivot between APM traces and logs.
  2. Use **Service Name** and **Environment** labels to narrow down scoped issues.
  3. Correlate infrastructure spikes (CPU/Memory) with specific APM transaction surges.

## Security (Auth, TLS, RBAC)
- **Common Issues**: TLS certificate expiration, SAML/OIDC authentication failures, unauthorized access (401/403 errors), or API key issues.
- **Troubleshooting Steps**:
  1. Verify TLS certificates using `openssl s_client -connect <host>:<port> -showcerts`.
  2. Check Elasticsearch and Kibana logs for `AuthenticationException` or `AuthorizationException`.
  3. Verify user roles and privileges using `GET /_security/user/<username>` and `GET /_security/role`.
- **In-Depth Methods**:
  1. Enable `TRACE` logging for `org.elasticsearch.xpack.security` to debug complex SAML/OIDC/Kerberos assertion flows.
  2. Analyze the Elasticsearch audit logs (if enabled) to track down specific rejected access attempts and their context.
  3. Inspect Kibana SAML login network payloads (using browser developer tools) for `SAMLResponse` errors or mismatched ACS URLs.