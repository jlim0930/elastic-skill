#!/bin/bash
set -e

echo "🚀 Initializing Elastic Stack AI Troubleshooting Project..."

# 1. Make local scripts executable
echo "⚙️  Making scripts executable..."
chmod +x scripts/*.sh

# 2. Setup Cursor IDE Rules (Local to project)
echo "🖱️  Setting up Cursor IDE rules (.cursor/rules)..."
mkdir -p .cursor/rules
for f in agents/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename -- "$f")
        name="${filename%.*}"
        cp "$f" ".cursor/rules/${name}.mdc"
    fi
done
echo "   ✅ Generated Cursor rules (.mdc files)."

# 3. Setup Gemini CLI (Global)
echo "♊ Setting up Gemini CLI..."
mkdir -p ~/.gemini/agents ~/.gemini/skills ~/.gemini/scripts
cp agents/*.md ~/.gemini/agents/ 2>/dev/null || true
cp -r skills/* ~/.gemini/skills/ 2>/dev/null || true
cp scripts/*.sh ~/.gemini/scripts/ 2>/dev/null || true
echo "   ✅ Gemini CLI environment updated."

echo ""
echo "🎉 Setup Complete!"
echo "👉 Cursor IDE users: You can now use @ rules in this directory."
echo "👉 Gemini CLI users: Agents and skills are installed globally."
echo "👉 Web LLM users: Check out BOOTSTRAP.md for Claude/ChatGPT setup."
