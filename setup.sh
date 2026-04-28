#!/bin/bash
set -e

echo "🚀 Initializing Elastic Stack AI Troubleshooting Project..."

# 1. Make local scripts executable
echo "⚙️  Making scripts executable..."
chmod +x scripts/*.sh

# 2. Setup Cursor IDE Rules (Global Helper)
echo "🖱️  Setting up Cursor IDE global helper..."
mkdir -p "$HOME/.elastic-ai-rules"
for f in agents/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename -- "$f")
        name="${filename%.*}"
        cp "$f" "$HOME/.elastic-ai-rules/${name}.mdc"
    fi
done

mkdir -p "$HOME/.local/bin"
INIT_SCRIPT="$HOME/.local/bin/elastic-cursor-init"
cat << 'EOF' > "$INIT_SCRIPT"
#!/bin/bash
echo "🔗 Linking Elastic AI Cursor rules to current directory..."
mkdir -p .cursor/rules
for f in "$HOME/.elastic-ai-rules/"*.mdc; do
    if [ -f "$f" ]; then
        ln -sf "$f" ".cursor/rules/$(basename "$f")"
    fi
done
echo "✅ Cursor rules linked! You can now use @ rules in this workspace."
EOF
chmod +x "$INIT_SCRIPT"

echo "   ✅ Generated global Cursor rules in ~/.elastic-ai-rules."
echo "   ✅ Created 'elastic-cursor-init' command in ~/.local/bin."

# 3. Setup Gemini CLI (Global)
echo "♊ Setting up Gemini CLI..."
mkdir -p ~/.gemini/agents ~/.gemini/skills ~/.gemini/scripts
cp agents/*.md ~/.gemini/agents/ 2>/dev/null || true
cp -r skills/* ~/.gemini/skills/ 2>/dev/null || true
cp scripts/*.sh ~/.gemini/scripts/ 2>/dev/null || true
echo "   ✅ Gemini CLI environment updated."

echo ""
echo "🎉 Setup Complete!"
echo "👉 Cursor IDE users: Run 'elastic-cursor-init' in any project folder to enable @ rules."
echo "   (Make sure ~/.local/bin is in your system's PATH)"
echo "👉 Gemini CLI users: Agents and skills are installed globally."
echo "👉 Web LLM users: Check out BOOTSTRAP.md for Claude/ChatGPT setup."
echo "👉 Official Skills: Extend this ecosystem with https://github.com/elastic/agent-skills"
