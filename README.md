# Elastic Stack AI Troubleshooting Ecosystem

This repository contains a specialized ecosystem of AI Agent Skills, Subagents, and Utility Scripts designed to troubleshoot, analyze, and optimize the Elastic Stack across all deployment models.

It is structured to act as a **Strategic Orchestrator**, breaking down complex observability, performance, and infrastructure issues into delegable tasks for specialized AI personas.

## 🤝 Official Elastic Resources

This ecosystem is deeply integrated with official Elastic resources to ensure accuracy and up-to-date troubleshooting. All agents follow a **Primary Source Protocol** that prioritizes:

*   **Documentation**: `https://www.elastic.co/docs`
*   **API Reference**: `https://www.elastic.co/docs/api/`
*   **GitHub Repositories**: `https://github.com/elastic`
*   **Agent Skills**: `https://github.com/elastic/agent-skills`

Agents are equipped with `web_fetch` and `google_web_search` to verify configuration syntax, API parameters, and version-specific behavior directly against these sources.

## 🧠 Continuous Learning & Self-Improvement

This ecosystem is designed to evolve. All skills and subagents are equipped with a **Continuous Learning Mandate** and the tools necessary (`save_memory`, `replace`, `write_file`) to edit their own source files.

When the AI successfully resolves a novel issue, writes a new ES|QL query, or discovers a repeatable workflow, it will proactively:
1.  **Update Rulebooks**: Append new heuristics into the `SKILL.md` or `references/` files.
2.  **Save Memory**: Retain user or environment-specific quirks across sessions.
3.  **Automate**: Write new bash scripts into the `scripts/` directory for future use.

---

## 🚀 Quick Start (Automated Setup)

We provide a universal setup script that automatically configures your environment and makes all utility scripts executable.

```bash
# Run the setup script from the project root
./setup.sh
```

---

## 🛠️ Requirements & CLI Installation

Most tools require **Node.js 18+**. Install via `brew install node` (macOS) or `sudo apt install nodejs` (WSL).

### 1. Gemini CLI (`gemini`)
*   **macOS (Homebrew)**: `brew install gemini-cli`
*   **macOS/WSL (npm)**: `npm install -g @google/gemini-cli`

### 2. Claude CLI (`claude`)
*   **macOS/WSL (Native)**: `curl -fsSL https://claude.ai/install.sh | bash`
*   **macOS/WSL (npm)**: `npm install -g @anthropic-ai/claude-code`

### 3. Cursor CLI (`cursor`)
*   **Editor Command**: 
    *   **macOS**: Command Palette (`Cmd+Shift+P`) -> "Shell Command: Install 'cursor' command in PATH"
    *   **WSL**: Run `cursor .` in your terminal to link your Windows installation.
*   **AI Agent (`cursor-agent`)**: `curl https://cursor.com/install -fsS | bash`

---

## Supported LLM Environments

### 1. Gemini CLI (Native Support)
The `setup.sh` script installs agents, skills, and utility scripts globally into `~/.gemini/`. 

*   **Usage**: Start a session and explicitly call an agent or let the CLI route your request automatically.
*   **Example Troubleshooting Flow**:
    1. Create a directory for your case: `mkdir -p diagnostics/issue-123 && cd diagnostics/issue-123`
    2. Copy relevant logs, JSON diagnostics, or screenshots into this folder.
    3. Run `gemini` in this directory.
    4. Ask: *"Analyze these logs and tell me why the cluster is red."*
    5. The CLI will automatically use the `elastic-expert` skill and specialized subagents to triage the files.

### 2. Cursor IDE (Global Helper Command)
Cursor requires `.mdc` rules to be in the local workspace. `setup.sh` installs a global helper command so you can instantly enable these rules in *any* project folder.

*   **Usage**: Navigate to your troubleshooting directory and run:
    ```bash
    elastic-cursor-init
    ```
*   **Result**: This creates a `.cursor/rules` folder and symlinks the personas. Use `@` mentions like `@elastic-log-analyzer` in Cursor Chat to trigger specialized analysis on your local files.

### 3. Web LLMs (ChatGPT / Claude.ai)
Open the `BOOTSTRAP.md` file and follow instructions to upload reference files into your Custom GPT or Claude Project.

---

## Repository Structure

```text
.
├── setup.sh            # Auto-installer for Cursor & Gemini CLI
├── skills/             # Deep contextual rulebooks for specific platforms
├── agents/             # Specialized subagent definitions (.md files)
└── scripts/            # Bash scripts for fast parsing of diagnostic JSONs/logs
```

## Included Utility Scripts

The `scripts/` directory contains bash scripts designed for LLMs to run via shell execution to save tokens when analyzing massive log files or JSON diagnostic bundles.

*   **`triage_json.sh`**: Rapidly extracts node stats, heap usage, and cluster health from heavy JSON responses.
*   **`triage_logs.sh`**: Summarizes the top 10 most frequent exceptions in an Elasticsearch or Kibana log file.
*   **`triage_allocation.sh`**: Quickly identifies why shards are unassigned from `_cat/shards` or `_cluster/allocation/explain` outputs.
*   **`triage_tasks.sh`**: Parses `_tasks?detailed=true` JSON to find the longest-running tasks and summarize task counts by action.
*   **`triage_hot_threads.sh`**: Condenses verbose `_nodes/hot_threads` output to show only thread names, CPU percentages, and the top-level blocking Java methods.
*   **`triage_memory.sh`**: Analyzes `_nodes/stats` to instantly surface nodes with high JVM heap pressure (>75%), GC issues, and tripped circuit breakers.
*   **`triage_circuit_breakers.sh`**: Deep dive into circuit breaker states, identifying both tripped breakers and those nearing their limits.
*   **`triage_sharding.sh`**: Analyzes shard sizes and distribution to identify oversized shards (>50GB) and shard count imbalances.
*   **`triage_pipelines.sh`**: Identifies failing ingest processors by aggregating error counts across all nodes.
*   **`triage_ilm.sh`**: Summarizes the status and configuration of Index Lifecycle Management (ILM) policies.
*   **`triage_summary.sh`**: Provides a high-level "at a glance" cluster health overview from various diagnostic files.
