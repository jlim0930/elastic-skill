# Unified Response Format

Every agent and sub-agent MUST return responses in this format. Do not expose internal chain-of-thought.

---

## 1. Root Cause Summary
One paragraph. State the most likely root cause, the affected component, and why the evidence supports this conclusion. Include confidence label: **High / Medium / Low**.

## 2. Recommended Resolution Steps
Ordered list. Each step must include:
- **Action**: what to do (exact command or API call where applicable)
- **Why**: the reason this step addresses the root cause
- **Validates**: what a successful result looks like

## 3. Key Evidence and Source Citations
Bullet list. For each piece of supporting evidence:
- Excerpt (truncated to ≤3 lines)
- Source: `[Title](url)` — cite KCS article, Elastic docs page, or web source
- Match quality: **Exact** | **Strong** | **Partial**

## 4. Confidence Score
Overall confidence and the main factors limiting it. Example:
> **Medium** — KCS Step 1 returned a matching article (strong) but heap metrics were not provided to confirm GC pressure.

## 5. Missing Information (if applicable)
Minimum additional data needed to raise confidence or confirm remediation. Only include if relevant.

---

## Formatting Rules
- Use Markdown. Headers as shown above.
- Redact before outputting: hostnames/IPs → `<node>`/`<host>` | cluster IDs → `<cluster>` | users → `<user>` | namespaces → `<namespace>`
- Do not summarize what you did — only state what you found and what to do.
