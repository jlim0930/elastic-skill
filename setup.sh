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

# 4. Setup MCP Docs Server (Docker)
echo "🐳 Setting up MCP Docs Server..."
if command -v docker >/dev/null 2>&1; then
    echo "   Cloning MCP server from external repo..."
    if [ ! -d "mcp-server" ]; then
        git clone https://github.com/jlim0930/mcp-server.git
    else
        cd mcp-server && git pull && cd ..
    fi
    
    cd mcp-server
    echo "   Configuring Elastic documentation sites..."
    # Update DOC_SITES to Elastic specific URLs
    sed -i.bak 's|DOC_SITES=.*|DOC_SITES=https://www.elastic.co/docs,https://www.elastic.co/docs/api,https://github.com/elastic|' docker-compose.yml
    
    # Add AUTO_INDEX if it doesn't exist
    if ! grep -q "AUTO_INDEX=" docker-compose.yml; then
        sed -i.bak '/DOC_SITES=/a\
      - AUTO_INDEX=true' docker-compose.yml
    fi

    echo "   Building and starting MCP server on port 8888..."
    docker compose up -d --build
    cd ..
    echo "   ✅ MCP Docs Server is running on http://localhost:8888"
else
    echo "   ⚠️  Docker not found. Skipping MCP server setup."
    echo "   (Install Docker to use the documentation indexing server)"
fi

echo ""
echo "🎉 Setup Complete!"
echo "👉 Cursor IDE users: Run 'elastic-cursor-init' in any project folder to enable @ rules."
echo "   (Make sure ~/.local/bin is in your system's PATH)"
echo "👉 Gemini CLI users: Agents and skills are installed globally."
echo "👉 Web LLM users: Check out BOOTSTRAP.md for Claude/ChatGPT setup."

# 5. Register MCP Server with LLMs
echo "🔌 Registering MCP Server with LLMs..."

# Gemini CLI
GEMINI_CONFIG_DIR="$HOME/.gemini"
GEMINI_SETTINGS_FILE="$GEMINI_CONFIG_DIR/settings.json"
mkdir -p "$GEMINI_CONFIG_DIR"

if [ ! -f "$GEMINI_SETTINGS_FILE" ]; then
    echo "{}" > "$GEMINI_SETTINGS_FILE"
fi

if python3 -c "
import json, os
file_path = os.path.expanduser('~/.gemini/settings.json')
try:
    with open(file_path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}

if 'mcpServers' not in data:
    data['mcpServers'] = {}

if 'elastic-docs' not in data['mcpServers']:
    data['mcpServers']['elastic-docs'] = {
        'url': 'http://localhost:8888/sse'
    }
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('updated')
" | grep -q "updated"; then
    echo "   ✅ Added elastic-docs to $GEMINI_SETTINGS_FILE"
else
    echo "   ✅ Gemini CLI already configured."
fi

# Claude Desktop (macOS)
CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

if [ -d "$CLAUDE_CONFIG_DIR" ]; then
    if [ ! -f "$CLAUDE_CONFIG_FILE" ]; then
        echo '{"mcpServers": {}}' > "$CLAUDE_CONFIG_FILE"
    fi
    
    # Use python to safely update the JSON file
    if python3 -c "
import json, os
file_path = os.path.expanduser('~/Library/Application Support/Claude/claude_desktop_config.json')
try:
    with open(file_path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}

if 'mcpServers' not in data:
    data['mcpServers'] = {}

if 'elastic-docs' not in data['mcpServers']:
    data['mcpServers']['elastic-docs'] = {
        'url': 'http://localhost:8888/sse'
    }
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('updated')
" | grep -q "updated"; then
        echo "   ✅ Added elastic-docs to Claude Desktop config."
    else
        echo "   ✅ Claude Desktop already configured."
    fi
else
    echo "   ℹ️  Claude Desktop not found, skipping."
fi

echo "   ℹ️  Cursor IDE: Please register manually via Settings -> Features -> MCP -> Add New MCP Server."
echo "      Name: elastic-docs, Type: SSE, URL: http://localhost:8888/sse"

