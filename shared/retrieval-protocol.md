# Knowledge Retrieval Protocol

Every agent and sub-agent MUST follow this exact sequence. Do NOT skip steps or run them in parallel.

## Priority Chain

### Step 1 — KCS MCP (Internal Knowledge Base)
Tool: `search_elastic_knowledge_base(query, page)`
- Formulate a concise keyword query from the symptom.
- Retrieve pages 1–3 maximum. Stop if a relevant match is found.
- Extract: `content_title`, `content_summary`, `source_url` from each result.
- If results are returned and relevant: proceed to **Resolve**. Skip Steps 2 and 3.

### Step 2 — Elastic Docs MCP (Official Documentation)
Tool: elastic-docs MCP (server: `elastic-docs` at `https://www.elastic.co/docs/_mcp/`)
- Only execute if Step 1 returned no relevant results.
- Query with the same keyword string, optionally narrowed to the relevant product area.
- Extract relevant passages. Summarize before embedding in prompts — do not paste full docs.
- If relevant results found: proceed to **Resolve**. Skip Step 3.

### Step 3 — Web Search (Last Resort)
Tool: `google_web_search` or `WebSearch`
- Only execute if Steps 1 and 2 both returned no relevant results.
- Scope searches to `site:elastic.co` first; broaden only if needed.
- Limit to 3 search queries maximum.

## KCS MCP Token Expiry — Detection and Recovery

The KCS MCP token is a **refresh token** valid for approximately 2 weeks. When it expires the tool
returns one of these error payloads:

```json
{"error": "No access token available. Restart the server with --login or set ELASTIC_AUTH_TOKEN."}
{"error": "Failed to fetch access token from Okta: 400 ..."}
```

**When you see either error, stop retrieval and do the following immediately:**

1. **Inform the user** — say exactly:
   > "Your KCS MCP authentication token has expired. I'll walk you through refreshing it."

2. **Run a quick server check** with `run_shell_command`:
   ```bash
   curl -s http://127.0.0.1:8001/mcp 2>&1 | head -3
   ```
   - If the server is unreachable: tell the user the server is not running and go to step 4.
   - If the server is running but returning 401: the refresh token itself has expired.

3. **Provide the token-capture command for the user to run** (browser login is required — the agent cannot automate this step):
   ```bash
   cd "$(dirname "$(which elastic-agent-kcs-start 2>/dev/null || echo "$HOME/kcs-mcp/KCS_search.py")")" && \
   uv run KCS_search.py --token
   ```
   Or, if the kcs-mcp path is known from context, run it directly with `run_shell_command`.

4. **Ask the user to paste the printed refresh token**, then write it to the `.env` file:
   ```bash
   echo 'ELASTIC_AUTH_TOKEN=<PASTED_TOKEN>' > /path/to/kcs-mcp/.env
   ```
   Replace `/path/to/kcs-mcp` with the actual path — use `run_shell_command` to do this automatically
   once the user provides the token.

5. **Restart the KCS MCP server** with `run_shell_command`:
   ```bash
   pkill -f "KCS_search.py" 2>/dev/null || true
   nohup uv run --directory /path/to/kcs-mcp KCS_search.py &
   sleep 3
   curl -s http://127.0.0.1:8001/mcp | head -1
   ```

6. **Resume from Step 1** of the retrieval chain once the server is confirmed healthy.

> **Never skip the user notification step.** Token expiry is not a silent fallback — it means KCS is
> unavailable and the user needs to act. Surface this immediately before continuing with Docs or Web.

---

## Retry and Loop Limits
- Maximum 3 retry attempts per retrieval step (e.g., rephrasing query).
- If all 3 steps return nothing useful, surface the best partial analysis with **Low** confidence.
- Do NOT re-retrieve information already present in context.

## Token Budget Rules
- Never load large files (>1 MB) in full. Use `grep_search`, `awk`, `sed`, or `jq` to extract relevant lines first.
- Summarize or truncate retrieved docs before embedding in any LLM call.
- Keep each agent's context focused on the active sub-problem only.

## Time Budget
- Hard limit: **5 minutes end-to-end** per query.
- If the limit is approaching, surface the best partial result rather than continuing retrieval.
- Track retrieval time: Step 1 ≤ 60s | Step 2 ≤ 90s | Step 3 ≤ 60s | Analysis ≤ 120s.
