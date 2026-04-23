# Elastic Stack AI Troubleshooting Ecosystem

This repository contains a specialized ecosystem of AI Agent Skills, Subagents, Utility Scripts, and a **Documentation MCP Server** designed to troubleshoot, analyze, and optimize the Elastic Stack across all deployment models.

It is structured to act as a **Strategic Orchestrator**, breaking down complex observability, performance, and infrastructure issues into delegable tasks for specialized AI personas, while providing deep RAG-based access to the latest Elastic documentation.

## 🚀 Quick Start (Automated Setup)

We provide a universal setup script that automatically configures your environment, builds the MCP server, makes all utility scripts executable, and auto-registers the MCP server with Gemini CLI and Claude Desktop.

```bash
# Run the setup script from the project root
./setup.sh
```

---

## Documentation MCP Server

This project uses the [mcp-server](https://github.com/jlim0930/mcp-server) to allow your AI to crawl, index, and search across Elastic documentation, GitHub repositories, and API references in real-time.

### ✨ Automated Setup (Recommended)
If you ran `./setup.sh` in the Quick Start phase, **you are already done!** The script automatically:
1. Clones the `mcp-server` repository.
2. Injects the target URLs from `mcp-docs.env`.
3. Builds and starts the Docker container on port `8888`.
4. Bootstraps **Gemini CLI** and **Claude Desktop** by registering the MCP server in their respective configuration files.

### 🐳 Manual Server Startup
If you prefer not to use the setup script, you can start the server manually:
```bash
git clone https://github.com/jlim0930/mcp-server.git
cp mcp-docs.env mcp-server/.env
cd mcp-server
# Ensure docker-compose.yml reads DOC_SITES=${DOC_SITES}
docker compose up -d --build
```
*   **Default Port**: `8888`
*   **Configured Sites**: Controlled via the `DOC_SITES` variable inside the `mcp-docs.env` file. (Auto-indexing is triggered automatically on startup when sites are configured).

### 🔌 Manual LLM Bootstrapping
If you are using an environment that wasn't automatically configured (like **Cursor IDE**), or want to set it up manually:

#### 1. Gemini CLI
Add to your `~/.gemini/config.yaml`:

**Option A: SSE (Recommended)**
```yaml
mcpServers:
  elastic-docs:
    url: http://localhost:8888/sse
```

**Option B: stdio**
```yaml
mcpServers:
  elastic-docs:
    command: docker
    args: ["run", "-i", "--rm", "elastic-mcp-docs"]
```

#### 2. Claude Desktop
Add to your `claude_desktop_config.json`:

**Option A: SSE (Recommended)**
```json
{
  "mcpServers": {
    "elastic-docs": {
      "url": "http://localhost:8888/sse"
    }
  }
}
```

**Option B: stdio**
```json
{
  "mcpServers": {
    "elastic-docs": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "elastic-mcp-docs"]
    }
  }
}
```

#### 3. Cursor IDE
1. Open **Cursor Settings** -> **Features** -> **MCP**.
2. Click **+ Add New MCP Server**.
3. **Name**: `elastic-docs`
4. **Type**: Select **SSE** (Recommended) or **command**.
5. **URL (SSE)**: `http://localhost:8888/sse`
6. **Command (command)**: `docker run -i --rm elastic-mcp-docs`

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
├── mcp-docs.env        # Configuration for the documentation crawler
├── mcp-server/         # (Auto-cloned) External MCP server for documentation RAG
├── skills/             # Deep contextual rulebooks for specific platforms
├── agents/             # Specialized subagent definitions (.md files)
└── scripts/            # Bash scripts for fast parsing of diagnostic JSONs/logs
```

## Included Utility Scripts

The `scripts/` directory contains bash scripts designed for LLMs to run via shell execution to save tokens when analyzing massive log files or JSON diagnostic bundles.

*   **`triage_json.sh`**: Rapidly extracts node stats, heap usage, and cluster health from heavy JSON responses.
*   **`triage_logs.sh`**: Summarizes the top 10 most frequent exceptions in an Elasticsearch or Kibana log file.
*   **`triage_allocation.sh`**: Quickly identifies why shards are unassigned from `_cat/shards` or `_cluster/allocation/explain` outputs.
