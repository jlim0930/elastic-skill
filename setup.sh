#!/bin/bash
# setup.sh — Elastic Stack AI Troubleshooting System
# Installs skills/agents, configures KCS MCP + Elastic Docs MCP for
# Claude Code CLI, Claude Desktop, Gemini CLI, and Cursor IDE.

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

ok()   { echo -e "  ${GREEN}✓${RESET} $*"; }
info() { echo -e "  ${CYAN}→${RESET} $*"; }
warn() { echo -e "  ${YELLOW}!${RESET} $*"; }
fail() { echo -e "  ${RED}✗${RESET} $*"; }
step() { echo -e "\n${BOLD}$*${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT_REPO_URL="git@github.com:elastic/support.git"
SUPPORT_REPO_DIR="${HOME}/.elastic-ai/support"
KCS_MCP_DIR="${SUPPORT_REPO_DIR}/ai-tools/kcs-mcp"

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Elastic Stack AI Troubleshooting — Setup           ║"
echo "║   Skills + KCS MCP + Elastic Docs MCP               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Prerequisites
# ─────────────────────────────────────────────────────────────────────────────
step "Step 1: Checking prerequisites..."

HAS_UV=0
HAS_NPX=0
HAS_PYTHON3=0

if command -v uv &>/dev/null; then
    ok "uv $(uv --version 2>/dev/null | head -1)"
    HAS_UV=1
else
    warn "uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv &>/dev/null; then
        ok "uv installed."
        HAS_UV=1
    else
        fail "uv installation failed. Install manually: https://github.com/astral-sh/uv"
    fi
fi

if command -v npx &>/dev/null; then
    ok "npx $(npx --version 2>/dev/null)"
    HAS_NPX=1
else
    warn "npx not found (Node.js required for Cursor/Claude Desktop/Gemini mcp-remote bridge)."
    warn "Install Node.js: https://nodejs.org/"
fi

if command -v python3 &>/dev/null; then
    ok "python3 $(python3 --version 2>/dev/null)"
    HAS_PYTHON3=1
fi

if command -v git &>/dev/null; then
    ok "git $(git --version 2>/dev/null | head -1)"
else
    warn "git not found — kcs-mcp cannot be cloned from GitHub. Install git: https://git-scm.com/"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: KCS MCP — Install dependencies
# ─────────────────────────────────────────────────────────────────────────────
step "Step 2: Setting up KCS MCP..."

KCS_AVAILABLE=0
if ! command -v git &>/dev/null; then
    warn "git not found — cannot clone kcs-mcp from GitHub. Install git and re-run."
elif [ -d "${SUPPORT_REPO_DIR}/.git" ]; then
    info "Updating kcs-mcp from GitHub..."
    git -C "${SUPPORT_REPO_DIR}" sparse-checkout init --cone --quiet 2>/dev/null || true
    git -C "${SUPPORT_REPO_DIR}" sparse-checkout set ai-tools/kcs-mcp --quiet 2>/dev/null || true
    git -C "${SUPPORT_REPO_DIR}" pull --quiet 2>/dev/null || true
    if [ -d "${KCS_MCP_DIR}" ]; then
        ok "kcs-mcp updated."
        KCS_AVAILABLE=1
    else
        warn "Existing clone incomplete; re-cloning..."
        rm -rf "${SUPPORT_REPO_DIR:?}"
        if git clone --filter=blob:none --sparse "${SUPPORT_REPO_URL}" "${SUPPORT_REPO_DIR}" \
            && git -C "${SUPPORT_REPO_DIR}" sparse-checkout set ai-tools/kcs-mcp; then
            ok "kcs-mcp re-cloned from ${SUPPORT_REPO_URL}."
            KCS_AVAILABLE=1
        else
            fail "Failed to clone from ${SUPPORT_REPO_URL}."
            warn "Ensure you have access to the elastic/support GitHub repository."
        fi
    fi
else
    info "Cloning kcs-mcp from GitHub (sparse checkout)..."
    mkdir -p "$(dirname "${SUPPORT_REPO_DIR}")"
    if git clone --filter=blob:none --sparse "${SUPPORT_REPO_URL}" "${SUPPORT_REPO_DIR}" \
        && git -C "${SUPPORT_REPO_DIR}" sparse-checkout set ai-tools/kcs-mcp; then
        ok "kcs-mcp cloned from ${SUPPORT_REPO_URL}."
        KCS_AVAILABLE=1
    else
        fail "Failed to clone from ${SUPPORT_REPO_URL}."
        warn "Ensure you have access to the elastic/support GitHub repository."
    fi
fi

if [ "${KCS_AVAILABLE}" = "1" ] && [ "${HAS_UV}" = "1" ]; then
    info "Installing Python dependencies for kcs-mcp..."
    if (cd "${KCS_MCP_DIR}" && uv venv && uv pip install -r requirements.txt); then
        ok "kcs-mcp dependencies installed."
    else
        fail "Failed to install kcs-mcp dependencies. See output above."
        KCS_AVAILABLE=0
    fi

    # ── Token setup ──────────────────────────────────────────────────────────
    ENV_FILE="${KCS_MCP_DIR}/.env"
    NEEDS_TOKEN=0

    if [ -f "${ENV_FILE}" ]; then
        if grep -q "ELASTIC_AUTH_TOKEN=" "${ENV_FILE}" 2>/dev/null; then
            TOKEN_VAL=$(grep "ELASTIC_AUTH_TOKEN=" "${ENV_FILE}" | cut -d= -f2- | tr -d '"' | tr -d "'")
            if [ -n "${TOKEN_VAL}" ] && [ "${TOKEN_VAL}" != "your_auth_token_here" ]; then
                ok "KCS auth token found in .env"
            else
                NEEDS_TOKEN=1
            fi
        else
            NEEDS_TOKEN=1
        fi
    elif [ -n "${ELASTIC_AUTH_TOKEN}" ]; then
        ok "KCS auth token found in environment variable."
        echo "ELASTIC_AUTH_TOKEN=${ELASTIC_AUTH_TOKEN}" > "${ENV_FILE}"
        ok "Saved token to ${ENV_FILE}"
    else
        NEEDS_TOKEN=1
    fi

    if [ "${NEEDS_TOKEN}" = "1" ]; then
        echo ""
        echo -e "${YELLOW}  ┌─────────────────────────────────────────────────────┐${RESET}"
        echo -e "${YELLOW}  │  KCS Authentication Required                         │${RESET}"
        echo -e "${YELLOW}  └─────────────────────────────────────────────────────┘${RESET}"
        echo ""
        echo "  The KCS MCP server requires an Elastic Okta refresh token."
        echo "  This token lasts ~2 weeks and is renewed automatically on each use."
        echo ""
        echo "  To capture your token, run the following command in a new terminal:"
        echo ""
        echo -e "  ${BOLD}  cd \"${KCS_MCP_DIR}\" && uv run KCS_search.py --token${RESET}"
        echo ""
        echo "  A Chrome browser will open. Log in with your Elastic Okta credentials."
        echo "  The refresh token will be printed to the terminal."
        echo ""
        read -rp "  Paste the refresh token here (or press Enter to skip): " INPUT_TOKEN
        if [ -n "${INPUT_TOKEN}" ]; then
            echo "ELASTIC_AUTH_TOKEN=${INPUT_TOKEN}" > "${ENV_FILE}"
            ok "Token saved to ${ENV_FILE}"
        else
            warn "No token provided. KCS MCP will return errors until a token is set."
            warn "To add it later:  echo 'ELASTIC_AUTH_TOKEN=<token>' > ${ENV_FILE}"
        fi
    fi

    # ── Remove any previously generated helper scripts before re-creating ────
    rm -f "${SCRIPT_DIR}/start-kcs-mcp.sh" \
          "${SCRIPT_DIR}/stop-kcs-mcp.sh" \
          "${SCRIPT_DIR}/refresh-kcs-token.sh" 2>/dev/null || true

    # ── Create start script ───────────────────────────────────────────────────
    START_SCRIPT="${SCRIPT_DIR}/start-kcs-mcp.sh"
    cat > "${START_SCRIPT}" << STARTEOF
#!/bin/bash
# start-kcs-mcp.sh — Start the KCS MCP server
# Run this before using Claude, Gemini, or Cursor for Elastic troubleshooting.
set -e

KCS_DIR="${KCS_MCP_DIR}"
ENV_FILE="\${KCS_DIR}/.env"
PORT=8001

# Check if already running
if curl -s "http://127.0.0.1:\${PORT}/mcp" &>/dev/null; then
    echo "KCS MCP server is already running on port \${PORT}."
    exit 0
fi

# Check token
if [ ! -f "\${ENV_FILE}" ] || ! grep -q "ELASTIC_AUTH_TOKEN=" "\${ENV_FILE}"; then
    echo "ERROR: No KCS auth token found at \${ENV_FILE}"
    echo "Run: cd \"\${KCS_DIR}\" && uv run KCS_search.py --token"
    echo "Then: echo 'ELASTIC_AUTH_TOKEN=<token>' > \${ENV_FILE}"
    exit 1
fi

echo "Starting KCS MCP server on http://127.0.0.1:\${PORT}/mcp ..."
cd "\${KCS_DIR}"
nohup uv run --env-file "\${ENV_FILE}" KCS_search.py > /tmp/kcs-mcp.log 2>&1 &
KCS_PID=\$!
echo \$KCS_PID > /tmp/kcs-mcp.pid
sleep 2

if curl -s "http://127.0.0.1:\${PORT}/mcp" &>/dev/null; then
    echo "KCS MCP server started (PID \${KCS_PID})."
    echo "Log: /tmp/kcs-mcp.log"
else
    echo "ERROR: Server did not start. Check /tmp/kcs-mcp.log"
    cat /tmp/kcs-mcp.log
    exit 1
fi
STARTEOF
    chmod +x "${START_SCRIPT}"
    ok "start-kcs-mcp.sh created at ${START_SCRIPT}"

    # ── Create token refresh script ───────────────────────────────────────────
    REFRESH_SCRIPT="${SCRIPT_DIR}/refresh-kcs-token.sh"
    cat > "${REFRESH_SCRIPT}" << REFRESHEOF
#!/bin/bash
# refresh-kcs-token.sh — Refresh the KCS MCP authentication token.
# Run this when your token expires (typically every 2 weeks).
set -e

KCS_DIR="${KCS_MCP_DIR}"
ENV_FILE="\${KCS_DIR}/.env"

echo "════════════════════════════════════════════════════"
echo "  KCS MCP Token Refresh"
echo "════════════════════════════════════════════════════"
echo ""
echo "A browser will open. Log in with your Elastic Okta credentials."
echo "The new refresh token will be printed below."
echo ""
cd "\${KCS_DIR}"
uv run KCS_search.py --token
echo ""
read -rp "Paste the new refresh token here: " NEW_TOKEN
if [ -n "\${NEW_TOKEN}" ]; then
    echo "ELASTIC_AUTH_TOKEN=\${NEW_TOKEN}" > "\${ENV_FILE}"
    echo "Token saved to \${ENV_FILE}"

    # Restart the server if it was running
    if [ -f /tmp/kcs-mcp.pid ]; then
        OLD_PID=\$(cat /tmp/kcs-mcp.pid)
        kill "\${OLD_PID}" 2>/dev/null || true
        rm -f /tmp/kcs-mcp.pid
        echo "Stopped old server (PID \${OLD_PID})."
    fi

    echo "Starting KCS MCP server with new token..."
    nohup uv run --env-file "\${ENV_FILE}" KCS_search.py > /tmp/kcs-mcp.log 2>&1 &
    NEW_PID=\$!
    echo \$NEW_PID > /tmp/kcs-mcp.pid
    sleep 2
    if curl -s "http://127.0.0.1:8001/mcp" &>/dev/null; then
        echo "KCS MCP server restarted successfully (PID \${NEW_PID})."
    else
        echo "ERROR: Server did not start. Check /tmp/kcs-mcp.log"
    fi
else
    echo "No token provided. Token was not updated."
fi
REFRESHEOF
    chmod +x "${REFRESH_SCRIPT}"
    ok "refresh-kcs-token.sh created at ${REFRESH_SCRIPT}"

    # ── Create stop script ────────────────────────────────────────────────────
    STOP_SCRIPT="${SCRIPT_DIR}/stop-kcs-mcp.sh"
    cat > "${STOP_SCRIPT}" << STOPEOF
#!/bin/bash
# stop-kcs-mcp.sh — Stop the KCS MCP server
PORT=8001

if [ -f /tmp/kcs-mcp.pid ]; then
    PID=\$(cat /tmp/kcs-mcp.pid)
    if kill "\${PID}" 2>/dev/null; then
        echo "KCS MCP server stopped (PID \${PID})."
    else
        echo "Process \${PID} not found; may have already stopped."
    fi
    rm -f /tmp/kcs-mcp.pid
else
    # Fall back to pkill if no pid file
    if pkill -f "KCS_search.py" 2>/dev/null; then
        echo "KCS MCP server stopped."
    else
        echo "KCS MCP server is not running."
    fi
fi
STOPEOF
    chmod +x "${STOP_SCRIPT}"
    ok "stop-kcs-mcp.sh created at ${STOP_SCRIPT}"
else
    warn "KCS MCP setup skipped (kcs-mcp unavailable or uv not found)."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helper: replace OUR MCP server entries in a JSON settings file.
# Removes the two keys we own (kcs-search, elastic-docs) then writes the new
# definitions.  All other keys in mcpServers are preserved untouched.
# Requires python3 (available via uv if not globally installed).
# ─────────────────────────────────────────────────────────────────────────────
replace_mcp_servers() {
    local TARGET_FILE="$1"
    local NEW_SERVERS_JSON="$2"

    if [ ! -f "${TARGET_FILE}" ]; then
        echo "{}" > "${TARGET_FILE}"
    fi

    PYTHON_BIN="python3"
    command -v python3 &>/dev/null || PYTHON_BIN="uv run python3"

    ${PYTHON_BIN} - << PYEOF
import json

with open("${TARGET_FILE}") as f:
    try:
        cfg = json.load(f)
    except json.JSONDecodeError:
        cfg = {}

# Remove only the keys this script owns so stale config never lingers.
# Any other MCP servers the user added are preserved.
OUR_KEYS = ["kcs-search", "elastic-docs"]
cfg.setdefault("mcpServers", {})
removed = [k for k in OUR_KEYS if cfg["mcpServers"].pop(k, None) is not None]
if removed:
    print(f"  removed stale entries: {', '.join(removed)}")

new_servers = ${NEW_SERVERS_JSON}
cfg["mcpServers"].update(new_servers)

if not cfg["mcpServers"]:
    del cfg["mcpServers"]

with open("${TARGET_FILE}", "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Build the MCP servers JSON snippet (used in all tool configs)
# ─────────────────────────────────────────────────────────────────────────────
# For Claude Code CLI: native HTTP type (no mcp-remote needed)
CLAUDE_CODE_SERVERS='{
  "kcs-search": {
    "type": "http",
    "url": "http://127.0.0.1:8001/mcp"
  },
  "elastic-docs": {
    "type": "http",
    "url": "https://www.elastic.co/docs/_mcp/"
  }
}'

# For tools that need mcp-remote bridge (Claude Desktop, Gemini CLI, Cursor)
if [ "${HAS_NPX}" = "1" ]; then
    BRIDGE_KCS='{
  "kcs-search": {
    "command": "npx",
    "args": ["-y", "mcp-remote", "http://127.0.0.1:8001/mcp"],
    "env": {"MCP_TRANSPORT_STRATEGY": "http-only"}
  },
  "elastic-docs": {
    "command": "npx",
    "args": ["-y", "mcp-remote", "https://www.elastic.co/docs/_mcp/"],
    "env": {"MCP_TRANSPORT_STRATEGY": "http-only"}
  }
}'
else
    BRIDGE_KCS='{}'
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helper: clean-install skills and agents to a target directory pair.
#
# Sub-agents are installed as  <domain>-<filename>.md  (e.g. ece-cluster-health.md)
# so same-named files from different domains never collide in the flat agents dir.
#
# A manifest file (.elastic-ai-manifest) is written next to the installed agents
# after each run.  On the next run the manifest is read first and every listed
# file is deleted — this catches files from previous versions whose names have
# since changed, which the source-list loop alone cannot detect.
#
# Only files we own are ever deleted; any agent the user created independently
# is left untouched.
# ─────────────────────────────────────────────────────────────────────────────
install_skills() {
    local TARGET_AGENTS="$1"
    local TARGET_SKILLS="$2"
    local MANIFEST="${TARGET_AGENTS}/.elastic-ai-manifest"

    mkdir -p "${TARGET_AGENTS}" "${TARGET_SKILLS}"

    # ── Pass 1: remove every file recorded in the previous-run manifest ───────
    # This handles renames: if a sub-agent was called foo.md last time but
    # bar.md now, the manifest deletes foo.md before bar.md is written.
    if [ -f "${MANIFEST}" ]; then
        while IFS= read -r fname; do
            [ -n "${fname}" ] && rm -f "${TARGET_AGENTS}/${fname}" 2>/dev/null || true
        done < "${MANIFEST}"
        rm -f "${MANIFEST}"
    fi

    # ── Pass 2: remove by current source names (handles fresh installs with no
    #    manifest, and skill-directory cleanup which the manifest doesn't cover) ─
    for domain in "${SCRIPT_DIR}/skills"/*/; do
        domain_name=$(basename "${domain}")
        rm -f "${TARGET_AGENTS}/${domain_name}.md" 2>/dev/null || true
        if [ -d "${domain}/sub-agents" ]; then
            for sub in "${domain}/sub-agents/"*.md; do
                [ -f "${sub}" ] && rm -f "${TARGET_AGENTS}/${domain_name}-$(basename "${sub}")" 2>/dev/null || true
            done
        fi
        rm -rf "${TARGET_SKILLS:?}/${domain_name}" 2>/dev/null || true
    done
    rm -rf "${TARGET_SKILLS:?}/shared" 2>/dev/null || true

    # ── Copy current source + write new manifest ──────────────────────────────
    : > "${MANIFEST}"   # create/truncate

    for domain in "${SCRIPT_DIR}/skills"/*/; do
        domain_name=$(basename "${domain}")

        if [ -f "${domain}/SKILL.md" ]; then
            cp "${domain}/SKILL.md" "${TARGET_AGENTS}/${domain_name}.md"
            echo "${domain_name}.md" >> "${MANIFEST}"
        fi

        if [ -d "${domain}/sub-agents" ]; then
            for sub in "${domain}/sub-agents/"*.md; do
                if [ -f "${sub}" ]; then
                    dest="${domain_name}-$(basename "${sub}")"
                    cp "${sub}" "${TARGET_AGENTS}/${dest}"
                    echo "${dest}" >> "${MANIFEST}"
                fi
            done
        fi

        cp -r "${domain}" "${TARGET_SKILLS}/${domain_name}/"
    done

    if [ -d "${SCRIPT_DIR}/shared" ]; then
        cp -r "${SCRIPT_DIR}/shared" "${TARGET_SKILLS}/shared/"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Claude Code CLI
# ─────────────────────────────────────────────────────────────────────────────
step "Step 3: Configuring Claude Code CLI (~/.claude/)..."

CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

install_skills "${CLAUDE_AGENTS_DIR}" "${CLAUDE_SKILLS_DIR}"
ok "Skills and agents installed to ~/.claude/"

# Write project-level .mcp.json (used when running claude from this directory)
cat > "${SCRIPT_DIR}/.mcp.json" << MCPEOF
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
MCPEOF
ok ".mcp.json written to ${SCRIPT_DIR}/.mcp.json (project-level, auto-loaded by Claude Code)"

# Merge into global Claude settings
replace_mcp_servers "${CLAUDE_SETTINGS}" "${CLAUDE_CODE_SERVERS}"
ok "MCP servers merged into ${CLAUDE_SETTINGS}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Claude Desktop
# ─────────────────────────────────────────────────────────────────────────────
step "Step 4: Configuring Claude Desktop..."

if [ "$(uname)" = "Darwin" ]; then
    CLAUDE_DESKTOP_CFG="${HOME}/Library/Application Support/Claude/claude_desktop_config.json"
    CLAUDE_DESKTOP_DIR="${HOME}/Library/Application Support/Claude"
elif [ "$(uname)" = "Linux" ]; then
    CLAUDE_DESKTOP_CFG="${HOME}/.config/Claude/claude_desktop_config.json"
    CLAUDE_DESKTOP_DIR="${HOME}/.config/Claude"
else
    CLAUDE_DESKTOP_CFG=""
fi

if [ -n "${CLAUDE_DESKTOP_CFG}" ]; then
    mkdir -p "${CLAUDE_DESKTOP_DIR}"
    if [ "${HAS_NPX}" = "1" ]; then
        replace_mcp_servers "${CLAUDE_DESKTOP_CFG}" "${BRIDGE_KCS}"
        ok "MCP servers merged into Claude Desktop config."
    else
        warn "npx not found — Claude Desktop MCP config skipped."
        warn "Install Node.js then re-run setup.sh, or add manually (see README.md)."
    fi
else
    warn "Claude Desktop config path unknown for this OS. See README.md for manual setup."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: Gemini CLI
# ─────────────────────────────────────────────────────────────────────────────
step "Step 5: Configuring Gemini CLI (~/.gemini/)..."

GEMINI_AGENTS="${HOME}/.gemini/agents"
GEMINI_SKILLS="${HOME}/.gemini/skills"
GEMINI_SETTINGS="${HOME}/.gemini/settings.json"

install_skills "${GEMINI_AGENTS}" "${GEMINI_SKILLS}"
ok "Skills and agents installed to ~/.gemini/"

if [ "${HAS_NPX}" = "1" ]; then
    # Gemini settings.json needs the mcpServers merged in
    if [ ! -f "${GEMINI_SETTINGS}" ]; then
        cat > "${GEMINI_SETTINGS}" << GEOF
{
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  }
}
GEOF
    fi
    replace_mcp_servers "${GEMINI_SETTINGS}" "${BRIDGE_KCS}"
    ok "MCP servers merged into ${GEMINI_SETTINGS}"
else
    warn "npx not found — Gemini MCP config skipped. Install Node.js and re-run."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6: Cursor IDE
# ─────────────────────────────────────────────────────────────────────────────
step "Step 6: Configuring Cursor IDE..."

# Install agent rules to global location for elastic-cursor-init.
# ~/.elastic-ai-rules is entirely owned by this script, so we wipe and
# re-populate it completely — no stale files, no collisions.
CURSOR_RULES_GLOBAL="${HOME}/.elastic-ai-rules"
rm -rf "${CURSOR_RULES_GLOBAL:?}"
mkdir -p "${CURSOR_RULES_GLOBAL}"
AGENT_COUNT=0

for domain in "${SCRIPT_DIR}/skills"/*/; do
    domain_name=$(basename "${domain}")
    if [ -f "${domain}/SKILL.md" ]; then
        cp "${domain}/SKILL.md" "${CURSOR_RULES_GLOBAL}/${domain_name}.mdc"
        AGENT_COUNT=$((AGENT_COUNT + 1))
    fi
    if [ -d "${domain}/sub-agents" ]; then
        for sub in "${domain}/sub-agents/"*.md; do
            if [ -f "${sub}" ]; then
                # Prefix with domain name to avoid collisions (e.g. ece-cluster-health.mdc)
                dest="${domain_name}-$(basename "${sub}" .md).mdc"
                cp "${sub}" "${CURSOR_RULES_GLOBAL}/${dest}"
                AGENT_COUNT=$((AGENT_COUNT + 1))
            fi
        done
    fi
done

ok "${AGENT_COUNT} agent rules installed to ${CURSOR_RULES_GLOBAL}"

# Create elastic-cursor-init helper
mkdir -p "${HOME}/.local/bin"
CURSOR_INIT="${HOME}/.local/bin/elastic-cursor-init"
cat > "${CURSOR_INIT}" << CURSORINIT
#!/bin/bash
echo "Linking Elastic AI rules to .cursor/rules/ ..."
mkdir -p .cursor/rules
for f in "\${HOME}/.elastic-ai-rules/"*.mdc; do
    [ -f "\$f" ] && ln -sf "\$f" ".cursor/rules/\$(basename \$f)"
done
echo "Done. Rules linked to .cursor/rules/"
CURSORINIT
chmod +x "${CURSOR_INIT}"

# Configure Cursor MCP
if [ "$(uname)" = "Darwin" ]; then
    CURSOR_MCP="${HOME}/.cursor/mcp.json"
elif [ "$(uname)" = "Linux" ]; then
    CURSOR_MCP="${HOME}/.config/cursor/mcp.json"
else
    CURSOR_MCP=""
fi

if [ -n "${CURSOR_MCP}" ] && [ "${HAS_NPX}" = "1" ]; then
    mkdir -p "$(dirname "${CURSOR_MCP}")"
    replace_mcp_servers "${CURSOR_MCP}" "${BRIDGE_KCS}"
    ok "MCP servers merged into ${CURSOR_MCP}"
elif [ -z "${CURSOR_MCP}" ]; then
    warn "Cursor MCP config path unknown for this OS. See README.md for manual steps."
else
    warn "npx not found — Cursor MCP config skipped."
fi
ok "'elastic-cursor-init' command created at ${HOME}/.local/bin"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7: Make utility scripts executable
# ─────────────────────────────────────────────────────────────────────────────
step "Step 7: Making helper scripts executable..."
chmod +x "${SCRIPT_DIR}"/start-kcs-mcp.sh \
         "${SCRIPT_DIR}"/stop-kcs-mcp.sh \
         "${SCRIPT_DIR}"/refresh-kcs-token.sh 2>/dev/null || true
ok "Helper scripts ready."

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Setup Complete${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""

if [ "${KCS_AVAILABLE}" = "1" ] && [ "${HAS_UV}" = "1" ]; then
    echo -e "  ${BOLD}Before using any LLM, start the KCS MCP server:${RESET}"
    echo ""
    echo -e "  ${CYAN}    ./start-kcs-mcp.sh${RESET}"
    echo ""
else
    warn "KCS MCP server scripts were not created (kcs-mcp unavailable or uv not found)."
    warn "Ensure git is installed, you have access to elastic/support, and uv is available."
    echo ""
fi

echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  Claude Code CLI                                 │"
echo "  │    claude                                        │"
echo "  │    (MCP auto-loaded from .mcp.json)              │"
echo "  ├─────────────────────────────────────────────────┤"
echo "  │  Gemini CLI                                      │"
echo "  │    gemini                                        │"
echo "  │    (MCP configured in ~/.gemini/settings.json)  │"
echo "  ├─────────────────────────────────────────────────┤"
echo "  │  Cursor IDE                                      │"
echo "  │    elastic-cursor-init  (in any project folder) │"
echo "  │    @elasticsearch-stack, @ece, @eck, @ech...    │"
echo "  ├─────────────────────────────────────────────────┤"
echo "  │  Claude Desktop                                  │"
echo "  │    Restart the app after setup                  │"
echo "  └─────────────────────────────────────────────────┘"
echo ""

if [ "${KCS_AVAILABLE}" = "1" ] && [ "${HAS_UV}" = "1" ]; then
    echo "  Token expired?"
    echo -e "  ${CYAN}    ./refresh-kcs-token.sh${RESET}"
    echo ""
fi

echo "  See README.md for full configuration details."
echo ""
