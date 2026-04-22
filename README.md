# Elastic Stack AI Troubleshooting Ecosystem

This repository contains a specialized ecosystem of AI Agent Skills, Subagents, and Utility Scripts designed to troubleshoot, analyze, and optimize the Elastic Stack across all deployment models (Self-managed, Elastic Cloud Hosted, Elastic Cloud Enterprise, and Elastic Cloud on Kubernetes).

It is structured to act as a **Strategic Orchestrator**, breaking down complex observability, performance, and infrastructure issues into delegable tasks for specialized AI personas.

## Repository Structure

```text
.
├── skills/          # Deep contextual rulebooks for specific platforms
│   ├── cloud-expert/  # Elastic Cloud Hosted (ECH)
│   ├── ece-expert/    # Elastic Cloud Enterprise (ECE)
│   ├── eck-expert/    # Elastic Cloud on Kubernetes (ECK)
│   └── elastic-expert/# General Stack & Self-Managed
├── agents/          # Specialized subagent definitions (.md files)
└── scripts/         # Bash scripts for fast parsing of diagnostic JSONs/logs
```

---

## 🚀 How to Import and Use

### 1. Gemini CLI (Native Support)

This ecosystem was built natively for the [Gemini CLI](https://github.com/google/gemini-cli). It heavily utilizes the `SKILL.md` architecture and the `~/.gemini/agents/` subagent delegation pattern.

**Installation:**
1. **Import Agents**: Copy the `.md` files into your global agents folder.
   ```bash
   mkdir -p ~/.gemini/agents
   cp agents/*.md ~/.gemini/agents/
   ```
2. **Import Skills**: Copy the skills directories.
   ```bash
   mkdir -p ~/.gemini/skills
   cp -r skills/* ~/.gemini/skills/
   ```
3. **Import Scripts**: Add the triage scripts to your scripts path.
   ```bash
   mkdir -p ~/.gemini/scripts
   cp scripts/*.sh ~/.gemini/scripts/
   chmod +x ~/.gemini/scripts/*.sh
   ```
**Usage**: Start a session and explicitly call an agent or let the CLI route your request automatically based on the symptoms provided.
```bash
gemini "@eck-expert analyze this diagnostic bundle and tell me why pods are crashing"
```

---

### 2. Cursor IDE

Cursor uses `.cursorrules` and the `.cursor/rules/` directory to manage AI behavior within a workspace. Because Cursor doesn't have an internal "delegation" architecture to route to subagents automatically, you will treat the *Skills* and *Agents* as explicit "Personas" you can invoke.

**Installation:**
1. Create the rules directory in your project root:
   ```bash
   mkdir -p .cursor/rules
   ```
2. Copy the agent definitions into the rules folder, renaming them to `.mdc` files:
   ```bash
   for f in agents/*.md; do cp "$f" ".cursor/rules/$(basename "$f" .md).mdc"; done
   ```
3. Add the reference guides (found in `skills/<expert-name>/references/`) to your project root or an `.ai-docs/` folder so Cursor can read them via `@` mentions.

**Usage**: In Cursor Chat (Cmd/Ctrl + L), explicitly call the persona or the reference document:
> "@elastic-platform-correlator Read @triage.md and analyze my recent log file."

---

### 3. Claude CLI / Aider

CLI tools like Claude CLI or Aider primarily rely on System Prompts, Architect flags, and context files.

**Installation & Usage:**
You will need to pass the Agent definition or Skill file as a system prompt or context file when you run the tool.

*Example with Aider:*
```bash
aider --message-file agents/elastic-upgrade-specialist.md
```

*Example loading context into Claude CLI:*
Load the relevant `SKILL.md` and reference files (like `heuristics.md`) directly into your context window using `/add` or by passing them as arguments depending on the specific CLI wrapper you are using.

---

### 4. Custom GPTs (ChatGPT) / Claude Projects (Claude.ai)

If you are using web-based LLMs, you can create a dedicated **Custom GPT** or **Claude Project** for Elastic troubleshooting.

**Installation:**
1. Create a new Custom GPT or Claude Project.
2. **Instructions / System Prompt**: Copy the contents of the `SKILL.md` from the platform you use most (e.g., `skills/elastic-expert/SKILL.md`) into the main instruction box.
3. **Knowledge Base / Project Files**: Upload all the `.md` files found in the `skills/<expert-name>/references/` folder.
4. **Agent Roles**: You can upload the `agents/` files as well. In your system prompt, instruct the AI: *"When faced with a specific sub-domain, read the corresponding agent markdown file from the knowledge base and adopt that persona."*

---

## Included Utility Scripts

The `scripts/` directory contains bash scripts designed for LLMs to run via shell execution to save tokens when analyzing massive log files or JSON diagnostic bundles.

*   **`triage_json.sh`**: Rapidly extracts node stats, heap usage, and cluster health from heavy JSON responses.
*   **`triage_logs.sh`**: Summarizes the top 10 most frequent exceptions in an Elasticsearch or Kibana log file.
*   **`triage_allocation.sh`**: Quickly identifies why shards are unassigned from `_cat/shards` or `_cluster/allocation/explain` outputs.
