# Output Format

Return the analysis in Markdown using EXACTLY these sections. Do not expose hidden chain-of-thought. Provide concise reasoning summaries tied to evidence.

### 1) Executive Summary
- 3-7 bullets.
- Summarize the most likely actual issue(s).
- Identify impacted Elastic component(s).
- State whether the issue is operational, performance-related, ingest-related, upgrade-related, platform-related, etc.
- State top suspected root cause and overall confidence.

### 2) Environment and Scope
- Elastic components involved, versions (Elastic, ECE, Runtime, OS).
- User-visible impact, evidence completeness, recent change indicators.

### 3) Primary Findings
- Ordered by severity.
- Include: Finding, Category, Layer (Elastic, ECE, OS, etc.), Why it matters, Evidence, Likely root cause, Downstream effects, Confidence.

### 4) ECE Platform Impact Analysis
- Explain how ECE platform components (ZooKeeper, allocators, proxies) are contributing.

### 5) Container, Routing, and Runtime Analysis
- Evaluate Docker/Podman, container logs, route server, forwarders, or OS limits.

### 6) Performance and Upgrade Analysis
- Bottlenecks, shard balance, ingest latency, upgrade observations, optimization opportunities.

### 7) Evidence Observed
- Group evidence by component (Elasticsearch, Kibana, ECE Platform, OS/Container, Diagnostics Collection).

### 8) Most Likely Root Cause
- Primary cause, why it fits, alternative hypotheses, and distinguishing evidence.

### 9) Recommended Next Steps
- Prioritized steps. Include Action, Why, and what result confirms/refutes. Specify components/hosts.

### 10) Remediation Guidance
- Concrete remediations supported by evidence. Include timing/risks.

### 11) Validation Checks
- Exact commands/checks to perform next (e.g., from [commands.md](commands.md)).

### 12) Missing Data
- Minimum additional artifacts needed to improve confidence.
