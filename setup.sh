#!/bin/bash
set -e

echo "Initializing Elastic Stack AI Troubleshooting Ecosystem..."

# 1. Make local scripts executable
echo "  Making scripts executable..."
chmod +x scripts/*.sh
SCRIPT_COUNT=$(ls scripts/*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "  ${SCRIPT_COUNT} scripts ready."

# 2. Setup Cursor IDE Rules (Global Helper)
echo "  Setting up Cursor IDE global helper..."
rm -f "$HOME/.elastic-ai-rules/"*.mdc 2>/dev/null || true
mkdir -p "$HOME/.elastic-ai-rules"
AGENT_COUNT=0
for f in agents/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename -- "$f")
        name="${filename%.*}"
        cp "$f" "$HOME/.elastic-ai-rules/${name}.mdc"
        AGENT_COUNT=$((AGENT_COUNT + 1))
    fi
done

mkdir -p "$HOME/.local/bin"
INIT_SCRIPT="$HOME/.local/bin/elastic-cursor-init"
cat << 'EOF' > "$INIT_SCRIPT"
#!/bin/bash
echo "Linking Elastic AI Cursor rules to current directory..."
mkdir -p .cursor/rules
for f in "$HOME/.elastic-ai-rules/"*.mdc; do
    if [ -f "$f" ]; then
        ln -sf "$f" ".cursor/rules/$(basename "$f")"
    fi
done
echo "Done. Use @elastic-expert, @elastic-log-analyzer, etc. in Cursor Chat."
EOF
chmod +x "$INIT_SCRIPT"

echo "  ${AGENT_COUNT} agent rules installed to ~/.elastic-ai-rules/"
echo "  'elastic-cursor-init' command created in ~/.local/bin"

# Helper: remove previously-installed agent .md files and skill subdirs before copying
_clean_and_install() {
    local target_agents="$1"
    local target_skills="$2"
    local target_scripts="$3"

    # Remove only the specific agent files we manage (preserves user-created agents)
    for f in agents/*.md; do
        [ -f "$f" ] && rm -f "${target_agents}/$(basename "$f")" 2>/dev/null || true
    done

    # Remove the skill subdirs we own, then recreate them
    for d in skills/*/; do
        [ -d "$d" ] && rm -rf "${target_skills}/$(basename "$d")" 2>/dev/null || true
    done

    # Remove only the specific script files we manage
    for f in scripts/*.sh; do
        [ -f "$f" ] && rm -f "${target_scripts}/$(basename "$f")" 2>/dev/null || true
    done

    mkdir -p "$target_agents" "$target_skills" "$target_scripts"
    cp agents/*.md "$target_agents/" 2>/dev/null || true
    cp -r skills/* "$target_skills/" 2>/dev/null || true
    cp scripts/*.sh "$target_scripts/" 2>/dev/null || true
}

# 3. Setup Gemini CLI (Global)
echo "  Setting up Gemini CLI..."
_clean_and_install ~/.gemini/agents ~/.gemini/skills ~/.gemini/scripts
echo "  Gemini CLI: agents, skills (including shared/), and scripts installed to ~/.gemini/"

# 4. Setup Claude CLI (Global)
echo "  Setting up Claude CLI..."
_clean_and_install ~/.claude/agents ~/.claude/skills ~/.claude/scripts
echo "  Claude CLI: agents, skills (including shared/), and scripts installed to ~/.claude/"

echo ""
echo "Setup complete."
echo ""
echo "  Claude CLI:  run 'claude' — elastic-expert routes automatically"
echo "  Gemini CLI:  run 'gemini' — elastic-expert routes automatically"
echo "  Cursor IDE:  run 'elastic-cursor-init' in any project folder (requires ~/.local/bin in PATH)"
echo "  Web LLM:     see BOOTSTRAP.md for Claude.ai / ChatGPT setup"
echo ""
echo "  ${AGENT_COUNT} specialist agents | ${SCRIPT_COUNT} diagnostic scripts | 4 platform skills"
echo "  Official skills: https://github.com/elastic/agent-skills"
