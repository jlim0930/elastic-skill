# Elastic Stack AI Troubleshooting Ecosystem

This repository contains a specialized ecosystem of AI Agent Skills, Subagents, and Utility Scripts designed to troubleshoot, analyze, and optimize the Elastic Stack across all deployment models (Self-managed, Elastic Cloud Hosted, Elastic Cloud Enterprise, and Elastic Cloud on Kubernetes).

It is structured to act as a **Strategic Orchestrator**, breaking down complex observability, performance, and infrastructure issues into delegable tasks for specialized AI personas.

## 🚀 Quick Start (Automated Setup)

We provide a universal setup script that automatically configures your environment for Gemini CLI and Cursor IDE, and makes all utility scripts executable.

```bash
# Run the setup script from the project root
./setup.sh
```

---

## Supported LLM Environments

### 1. Cursor IDE (Zero-Config)
After running `./setup.sh`, a `.cursor/rules` directory is generated automatically. 
*   **Usage**: Open this folder in Cursor. In Cursor Chat (Cmd/Ctrl + L), you can now explicitly call the personas via `@` mentions.
*   **Example**: `@elastic-log-analyzer Read the logs in /tmp/es.log and find the root cause.`

### 2. Gemini CLI (Native Support)
The `setup.sh` script installs the agents, skills, and utility scripts globally into `~/.gemini/`. 
*   **Usage**: Start a session and explicitly call an agent or let the CLI route your request automatically based on the symptoms provided.
*   **Example**: `gemini "@eck-expert analyze this diagnostic bundle and tell me why pods are crashing"`

### 3. Web LLMs (ChatGPT Custom GPTs / Claude Projects)
If you are using web interfaces, you can easily load this project into a persistent context.
*   **Usage**: Open the `BOOTSTRAP.md` file and follow the instructions to copy the Master Prompt and upload the reference files into your Custom GPT or Claude Project.

### 4. Claude CLI / Aider
CLI tools like Claude CLI or Aider primarily rely on System Prompts and context files.
*   **Usage**: Pass the relevant Agent definition or Skill file as a system prompt when you run the tool.
*   **Example (Aider)**: `aider --message-file agents/elastic-upgrade-specialist.md`

---

## Repository Structure

```text
.
├── setup.sh         # Auto-installer for Cursor & Gemini CLI
├── BOOTSTRAP.md     # Master prompt for ChatGPT/Claude.ai
├── skills/          # Deep contextual rulebooks for specific platforms
│   ├── cloud-expert/  # Elastic Cloud Hosted (ECH)
│   ├── ece-expert/    # Elastic Cloud Enterprise (ECE)
│   ├── eck-expert/    # Elastic Cloud on Kubernetes (ECK)
│   └── elastic-expert/# General Stack & Self-Managed
├── agents/          # Specialized subagent definitions (.md files)
└── scripts/         # Bash scripts for fast parsing of diagnostic JSONs/logs
```

## Included Utility Scripts

The `scripts/` directory contains bash scripts designed for LLMs to run via shell execution to save tokens when analyzing massive log files or JSON diagnostic bundles.

*   **`triage_json.sh`**: Rapidly extracts node stats, heap usage, and cluster health from heavy JSON responses.
*   **`triage_logs.sh`**: Summarizes the top 10 most frequent exceptions in an Elasticsearch or Kibana log file.
*   **`triage_allocation.sh`**: Quickly identifies why shards are unassigned from `_cat/shards` or `_cluster/allocation/explain` outputs.
