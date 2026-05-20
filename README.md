# Elastic Stack AI Troubleshooting System

A hierarchical multi-agent system for diagnosing and resolving issues across the Elastic Stack.
It uses two MCP knowledge sources — an internal KCS knowledge base and the official Elastic Docs —
before falling back to web search, so every answer is grounded in the most authoritative source
available.

---

## Architecture Overview

```
User query
    │
    ▼
Top-Level Skill (domain router)
    │  elasticsearch-stack / ech / ece / eck / elastic-agent
    │
    ├─▶ Sub-Agent (focused specialist)
    │       │
    │       └─▶ Retrieval Chain (strict order)
    │               1. KCS MCP  ──▶ search_elastic_knowledge_base()
    │               2. Elastic Docs MCP  ──▶ elastic-docs server tools
    │               3. Web Search  ──▶ google_web_search (last resort)
    │
    └─▶ (multi-domain) Merge + rank results → unified response
```

### Agents and Sub-Agents

| Top-Level Skill | Sub-Agents |
|---|---|
| `elasticsearch-stack` | cluster-health, shard-allocation, ilm-data-streams, mapping-conflicts, memory-pressure, ingest-performance |
| `ech` | deployment-plan, autoscaling, cluster-health, cloud-console |
| `ece` | zookeeper-health, proxy-routing, allocator-pressure, container-runtime, cluster-health |
| `eck` | operator-reconciliation, pod-scheduling, cluster-health, networking |
| `elastic-agent` | enrollment, fleet-policy, agent-health, standalone |

---

## MCP Servers

### 1. KCS MCP — Internal Knowledge Base
- **URL**: `http://127.0.0.1:8001/mcp` (local HTTP server you run)
- **Tools exposed**: `search_elastic_knowledge_base(query, page)`, `search_elastic_search_plus(query, page)`
- **Auth**: Elastic Okta refresh token (~2-week lifetime, auto-renewed)
- **Source**: `~/.elastic-ai/support/ai-tools/kcs-mcp/` (cloned from `git@github.com:elastic/support.git`)

### 2. Elastic Docs MCP — Official Elastic Documentation
- **URL**: `https://www.elastic.co/docs/_mcp/` (remote, always available)
- **Tools exposed**: Elastic documentation search and retrieval tools
- **Auth**: None required

---

## Prerequisites

| Tool | Required for | Install |
|---|---|---|
| [git](https://git-scm.com/) + SSH keys for `github.com` | Cloning kcs-mcp from `elastic/support` | https://docs.github.com/en/authentication/connecting-to-github-with-ssh |
| [uv](https://github.com/astral-sh/uv) | KCS MCP Python dependencies | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| [Node.js + npx](https://nodejs.org/) | Claude Desktop, Gemini CLI, Cursor (mcp-remote bridge) | https://nodejs.org/ |
| Chrome | KCS token capture (one-time login) | https://www.google.com/chrome/ |

> **SSH keys required**: `setup.sh` clones kcs-mcp from `git@github.com:elastic/support.git`
> via SSH. Ensure your SSH key is added to your GitHub account and that `ssh -T git@github.com`
> succeeds before running setup.

Claude Code CLI supports HTTP MCP servers natively — no Node.js needed for Claude Code.

---

## Quick Start

```bash
cd elastic-skill
./setup.sh
```

The setup script:
1. Installs KCS MCP Python dependencies via `uv`
2. Captures your KCS auth token (opens a browser for Okta login)
3. Installs skills and agents for Claude Code CLI, Gemini CLI, and Cursor
4. Writes MCP server configuration for each tool
5. Creates `start-kcs-mcp.sh` and `refresh-kcs-token.sh` helper scripts

Before every session, start the KCS MCP server:

```bash
./start-kcs-mcp.sh
```

---

## Configuring Each LLM Tool

### Claude Code CLI

Skills and agents are installed to `~/.claude/agents/` and `~/.claude/skills/`.
A project-level `.mcp.json` is written to the `elastic-skill/` directory — Claude Code
automatically loads it when you run `claude` from this directory.

**MCP config** (`.mcp.json` in this directory, also merged into `~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "kcs-search": {
      "type": "http",
      "url": "http://127.0.0.1:8001/mcp"
    },
    "elastic-docs": {
      "type": "http",
      "url": "https://www.elastic.co/docs/_mcp/"
    }
  }
}
```

**Usage:**

```bash
# Start the KCS MCP server first
./start-kcs-mcp.sh

# Then start Claude Code from this directory
claude
```

Invoke a skill directly: `/elasticsearch-stack` or ask any Elastic question — the router
selects the right top-level skill and sub-agent automatically.

---

### Claude Desktop

Config file location:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

`setup.sh` writes this automatically on macOS/Linux. For manual setup, merge the following into
the `mcpServers` object:

```json
{
  "mcpServers": {
    "kcs-search": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:8001/mcp"],
      "env": { "MCP_TRANSPORT_STRATEGY": "http-only" }
    },
    "elastic-docs": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://www.elastic.co/docs/_mcp/"],
      "env": { "MCP_TRANSPORT_STRATEGY": "http-only" }
    }
  }
}
```

> **Important**: Start `./start-kcs-mcp.sh` **before** opening Claude Desktop. The KCS MCP
> server must be running on `127.0.0.1:8001` before Claude Desktop connects to it.

Restart Claude Desktop after editing the config.

---

### Gemini CLI

`setup.sh` merges the MCP config into `~/.gemini/settings.json`.

For manual setup, add to `~/.gemini/settings.json`:

```json
{
  "security": {
    "auth": { "selectedType": "oauth-personal" }
  },
  "mcpServers": {
    "kcs-search": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:8001/mcp/"],
      "env": { "MCP_TRANSPORT_STRATEGY": "http-only" }
    },
    "elastic-docs": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://www.elastic.co/docs/_mcp/"],
      "env": { "MCP_TRANSPORT_STRATEGY": "http-only" }
    }
  }
}
```

Skills and agents are installed to `~/.gemini/agents/` and `~/.gemini/skills/`.

**Usage:**

```bash
./start-kcs-mcp.sh
gemini
```

---

### Cursor IDE

`setup.sh`:
- Installs agent rules (`.mdc` files) to `~/.elastic-ai-rules/`
- Merges MCP config into `~/.cursor/mcp.json` (macOS) or `~/.config/cursor/mcp.json` (Linux)
- Creates the `elastic-cursor-init` helper command

**Per-project setup** (run once per troubleshooting workspace):

```bash
elastic-cursor-init
```

This symlinks all agent rules to `.cursor/rules/` in the current directory.

**Usage in Cursor Chat:**

```
@elasticsearch-stack  My cluster is red — 3 primary shards unassigned...
@ece                  ZooKeeper leader election is failing on director-1...
@eck                  ECK operator reconciliation is stuck on MigratingData...
@ech                  Deployment plan fails at rolling-grow-and-shrink step...
@elastic-agent        Agent keeps showing degraded after enrolling...
```

**MCP config** (auto-written by `setup.sh`, or add manually to `~/.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "kcs-search": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:8001/mcp"],
      "env": { "MCP_TRANSPORT_STRATEGY": "http-only" }
    },
    "elastic-docs": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://www.elastic.co/docs/_mcp/"],
      "env": { "MCP_TRANSPORT_STRATEGY": "http-only" }
    }
  }
}
```

---

## KCS MCP Token Management

### How the Token Works

The KCS MCP server uses an Okta **refresh token** (not a short-lived access token):
- Valid for approximately **2 weeks**
- Each time an API call is made, the refresh token is silently exchanged for a new access token
- If the server restarts, it re-exchanges the refresh token automatically
- If you don't use KCS for more than 2 weeks, the refresh token itself expires and must be recaptured

Tokens are stored in `~/.elastic-ai/support/ai-tools/kcs-mcp/.env`:

```
ELASTIC_AUTH_TOKEN=<your_refresh_token>
```

### When Does the Token Expire?

The KCS MCP tool returns one of these errors when authentication fails:

```json
{"error": "No access token available. Restart the server with --login or set ELASTIC_AUTH_TOKEN."}
{"error": "Failed to fetch access token from Okta: 400 ..."}
```

**The AI will detect this automatically.** When a sub-agent calls `search_elastic_knowledge_base`
and receives either error, it will:

1. Stop retrieval immediately
2. Notify you: *"Your KCS MCP authentication token has expired."*
3. Walk you through the refresh steps below
4. Update `.env` and restart the server once you provide the new token
5. Resume from Step 1 of the retrieval chain

### Refreshing the Token

**Option A — Use the helper script (recommended):**

```bash
./refresh-kcs-token.sh
```

This opens a browser for Okta login, captures the new token, updates `.env`, and restarts
the server — all in one step.

**Option B — Manual refresh:**

```bash
# 1. Capture the new token (opens a browser)
cd ~/.elastic-ai/support/ai-tools/kcs-mcp && uv run KCS_search.py --token

# 2. Copy the printed token, then:
echo 'ELASTIC_AUTH_TOKEN=<your_new_token>' > ~/.elastic-ai/support/ai-tools/kcs-mcp/.env

# 3. Restart the server
pkill -f "KCS_search.py" && ./start-kcs-mcp.sh
```

**Option C — Login-on-start (no .env needed):**

```bash
cd ~/.elastic-ai/support/ai-tools/kcs-mcp && uv run KCS_search.py --login
```

This opens a browser, captures the token in memory, and starts the server immediately.
The token is not saved to disk — the server must be restarted this way every time.

### Starting/Stopping the Server

```bash
# Start
./start-kcs-mcp.sh

# Check if running
curl -s http://127.0.0.1:8001/mcp | head -3

# Stop
pkill -f "KCS_search.py"
# or:
kill $(cat /tmp/kcs-mcp.pid)

# View logs
tail -f /tmp/kcs-mcp.log
```

---

## How Skills and Sub-Agents Use the MCPs

### The Retrieval Chain (enforced in every sub-agent)

Every sub-agent follows `shared/retrieval-protocol.md` — a strict three-step chain that cannot
be skipped or reordered:

```
Step 1: KCS MCP
  └─▶ search_elastic_knowledge_base(query, page=1..3)
      ├─ Hit  → use result, skip Steps 2 and 3
      └─ Miss → go to Step 2

Step 2: Elastic Docs MCP
  └─▶ elastic-docs server search tool
      ├─ Hit  → use result, skip Step 3
      └─ Miss → go to Step 3

Step 3: Web Search (last resort)
  └─▶ google_web_search("site:elastic.co <query>")
      └─ Always surfaces some result; mark as Low confidence if not direct match
```

Each sub-agent includes pre-written KCS query strings tailored to its domain — for example,
the `cluster-health` sub-agent uses queries like `"cluster red unassigned primary"` and
`"master not discovered"`. These are not generic; they match the terminology used in actual
KCS articles.

### What the Top-Level Skills Do

Top-level SKILL.md files (`elasticsearch-stack`, `ech`, `ece`, `eck`, `elastic-agent`) are
**routers only**. They:

1. Scan the user's input for domain signal keywords (e.g., `"ZooKeeper"`, `"heap"`, `"rollover"`)
2. Dispatch to the matching sub-agent
3. For multi-domain issues: activate 2+ sub-agents, then merge and rank their results

Top-level skills do **not** call MCPs directly — that is the sub-agent's responsibility.

### What Sub-Agents Do

Each sub-agent is self-contained:

1. **Classify** the specific failure mode from the input
2. **Extract** relevant metrics using `grep`, `awk`, or `jq` (never full file loads)
3. **Retrieve** using the KCS → Docs → Web chain
4. **Analyze** the retrieved knowledge against the evidence
5. **Respond** using `shared/output-format.md` (root cause, steps, citations, confidence)

### Citation and Source Attribution

Every response includes source citations in the format:

```
[KCS: Article Title](https://support.elastic.dev/knowledge/view/<id>)
[Docs: Page Title](https://www.elastic.co/docs/...)
[Web: Source](https://...)
```

Responses include a **confidence score** (High / Medium / Low) and the primary factor limiting
confidence — so you always know how reliable the diagnosis is.

### Token Budget Enforcement

Sub-agents are instructed to:
- Use `grep` / `jq` to extract only relevant lines before passing content to the LLM
- Summarize retrieved docs — never paste full articles
- Keep a maximum of 3 retry attempts per retrieval step
- Respect the **5-minute end-to-end time limit** per query

---

## File Structure

```
elastic-skill/
├── setup.sh                        # Universal installer (run this first)
├── start-kcs-mcp.sh                # Start KCS MCP server (created by setup.sh)
├── refresh-kcs-token.sh            # Refresh expired KCS token (created by setup.sh)
├── .mcp.json                       # Project-level MCP config for Claude Code CLI
│
├── shared/
│   ├── retrieval-protocol.md       # KCS→Docs→Web chain + token refresh logic
│   ├── output-format.md            # Unified response format with confidence scores
│   ├── thresholds.md               # Critical thresholds (heap, disk, shards, etc.)
│   └── triage-phases.md            # 8-phase fallback triage sequence
│
└── skills/
    ├── elasticsearch-stack/
    │   ├── SKILL.md                # Router: routes to sub-agents by signal
    │   └── sub-agents/
    │       ├── cluster-health.md
    │       ├── shard-allocation.md
    │       ├── ilm-data-streams.md
    │       ├── mapping-conflicts.md
    │       ├── memory-pressure.md
    │       └── ingest-performance.md
    │
    ├── ech/
    │   ├── SKILL.md
    │   └── sub-agents/
    │       ├── deployment-plan.md
    │       ├── autoscaling.md
    │       ├── cluster-health.md
    │       └── cloud-console.md
    │
    ├── ece/
    │   ├── SKILL.md
    │   └── sub-agents/
    │       ├── zookeeper-health.md
    │       ├── proxy-routing.md
    │       ├── allocator-pressure.md
    │       ├── container-runtime.md
    │       └── cluster-health.md
    │
    ├── eck/
    │   ├── SKILL.md
    │   └── sub-agents/
    │       ├── operator-reconciliation.md
    │       ├── pod-scheduling.md
    │       ├── cluster-health.md
    │       └── networking.md
    │
    └── elastic-agent/
        ├── SKILL.md
        └── sub-agents/
            ├── enrollment.md
            ├── fleet-policy.md
            ├── agent-health.md
            └── standalone.md
```

---

## Troubleshooting Setup Issues

### KCS MCP server won't start
```bash
tail -50 /tmp/kcs-mcp.log
```
Common causes:
- Port 8001 already in use: `lsof -i :8001` then kill the occupying process.
- Missing token: run `./refresh-kcs-token.sh`.
- Python dependency issue: `cd ~/.elastic-ai/support/ai-tools/kcs-mcp && uv pip install -r requirements.txt`.

### Claude Code doesn't see the MCP servers
- Verify `.mcp.json` exists in the directory where you run `claude`.
- Check `~/.claude/settings.json` has a `mcpServers` key.
- Restart Claude Code after config changes.

### Gemini CLI doesn't see the MCP servers
- Verify `~/.gemini/settings.json` has a `mcpServers` key.
- Check `npx` is available: `npx --version`.

### Cursor rules not appearing
- Run `elastic-cursor-init` from your working directory.
- Verify `~/.local/bin` is in your `PATH`: `echo $PATH | grep local`.
- Check `.cursor/rules/` was created: `ls .cursor/rules/`.

### mcp-remote connection refused
The KCS MCP server is not running. Start it:
```bash
./start-kcs-mcp.sh
```

---

## Official Resources

- **Elastic Documentation**: https://www.elastic.co/docs
- **Elastic API Reference**: https://www.elastic.co/docs/api/
- **Elastic GitHub**: https://github.com/elastic
- **KCS Knowledge Base**: https://support.elastic.dev/knowledge/search (requires Elastic login)
