# Elastic Stack AI Troubleshooting Ecosystem

This repository contains a specialized ecosystem of AI Agent Skills, Subagents, and Utility Scripts designed to troubleshoot, analyze, and optimize the Elastic Stack across all deployment models.

It is structured to act as a **Strategic Orchestrator**, breaking down complex observability, performance, and infrastructure issues into delegable tasks for specialized AI personas.

## 🚀 Quick Start (Automated Setup)

We provide a universal setup script that automatically configures your environment and makes all utility scripts executable.

```bash
# Run the setup script from the project root
./setup.sh
```

---

## Supported LLM Environments

### 1. Cursor IDE (Global Helper Command)
Cursor requires `.mdc` rules to be in the local workspace. `setup.sh` installs a global helper command so you can instantly enable these rules in *any* project folder.
*   **Usage**: Navigate to any directory you want to troubleshoot in your terminal and run:
    ```bash
    elastic-cursor-init
    ```
*   **Result**: This creates a `.cursor/rules` folder and symlinks the personas. Use `@` mentions like `@elastic-log-analyzer` in Cursor Chat.

### 2. Gemini CLI (Native Support)
The `setup.sh` script installs agents, skills, and utility scripts globally into `~/.gemini/`. 
*   **Usage**: Start a session and explicitly call an agent or let the CLI route your request automatically.

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
