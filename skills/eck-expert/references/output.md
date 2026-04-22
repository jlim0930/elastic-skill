# Output Format

Return the analysis in Markdown using exactly these sections:

### 1) Executive Summary
- 3-7 bullets.
- Summarize issue, impacted components, root cause, and confidence.

### 2) Environment and Scope
- Versions (Elastic, ECK, K8s), impact, and evidence completeness.

### 3) Primary Findings (ordered by severity)
- Finding, Category, Layer, Why it matters, Evidence, Root cause, Downstream effects, Confidence.

### 4) ECK and Kubernetes Impact Analysis
- How ECK/K8s contributes to the issue (resources, objects, fields).

### 5) Performance and Upgrade Analysis
- Bottlenecks, shard balance, ingest latency, and upgrade observations.

### 6) Evidence Observed
- Grouped by component (Elasticsearch, Kibana, ECK/K8s, etc.).

### 7) Most Likely Root Cause
- Primary cause, fit, and alternative hypotheses.

### 8) Recommended Next Steps
- Action, Why, and what result would confirm/refute.

### 9) Remediation Guidance
- Concrete remediations, risks, and ECK/K8s resource areas involved.

### 10) Validation Checks
- Exact checks to be performed next.

### 11) Missing Data
- Minimum additional artifacts needed to improve confidence.
