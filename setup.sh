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
    
    echo "   Patching MCP server to utilize llm.zip for faster indexing..."
    cat << 'PATCHEOF' > mcp-server/patch_server.py
import sys

with open("server.py", "r") as f:
    content = f.read()

old_code = """async def run_indexing():
    \"\"\"
    Core logic for crawling and indexing sites.
    Shared by the tool and the automatic startup process.
    \"\"\"
    seed_sites = get_target_sites()
    if not seed_sites:
        print("Indexing skipped: No sites found in DOC_SITES.")
        return "Error: No sites found in DOC_SITES environment variable."
        
    try:
        crawl_delay = float(os.getenv("CRAWL_DELAY", "1.0"))
    except ValueError:
        crawl_delay = 1.0

    results_summary = []
    visited = set()
    queue = deque(seed_sites)

    async with AsyncWebCrawler() as crawler:
        while queue:
            current_url = queue.popleft()
            
            # Strip fragment (e.g., #section) to avoid duplicate crawling
            current_url, _ = urldefrag(current_url)
            
            if current_url in visited:
                continue
                
            visited.add(current_url)
            print(f"Indexing: {current_url}")
            
            # arun() fetches and converts to LLM-friendly Markdown automatically
            result = await crawler.arun(url=current_url)

            if result.success:
                # Upsert into vector store
                # We use the URL as the ID to avoid duplicate entries
                collection.upsert(
                    documents=[result.markdown],
                    metadatas=[{"source": current_url}],
                    ids=[current_url]
                )
                results_summary.append(f"✅ Indexed: {current_url}")
                
                # Recursively add internal links under the configured seed sites
                internal_links = result.links.get("internal", [])
                for link_obj in internal_links:
                    href = link_obj.get("href")
                    if href:
                        href_clean, _ = urldefrag(href)
                        # Ensure the link is within one of the root seed sites
                        if any(href_clean.startswith(seed) for seed in seed_sites):
                            if href_clean not in visited and href_clean not in queue:
                                queue.append(href_clean)
            else:
                results_summary.append(f"❌ Failed: {current_url} ({result.error_message})")
                
            # Throttle requests to be polite to the target server and local CPU
            if queue:
                await asyncio.sleep(crawl_delay)

    summary = "\\n".join(results_summary)
    print(f"Indexing complete:\\n{summary}")
    return summary"""

new_code = """async def run_indexing():
    \"\"\"
    Core logic for crawling and indexing sites.
    Shared by the tool and the automatic startup process.
    \"\"\"
    seed_sites = get_target_sites()
    if not seed_sites:
        print("Indexing skipped: No sites found in DOC_SITES.")
        return "Error: No sites found in DOC_SITES environment variable."
        
    try:
        crawl_delay = float(os.getenv("CRAWL_DELAY", "1.0"))
    except ValueError:
        crawl_delay = 1.0

    results_summary = []
    visited = set()
    
    # Optional: strip trailing slashes from seed sites
    normalized_seeds = []
    for s in seed_sites:
        normalized_seeds.append(s[:-1] if s.endswith('/') else s)
    seed_sites = normalized_seeds
    
    queue = deque(seed_sites)

    def fetch_and_process_zip():
        import urllib.request
        import zipfile
        import io
        zip_url = "https://www.elastic.co/docs/llm.zip"
        try:
            print(f"Downloading {zip_url}...")
            req = urllib.request.Request(zip_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as response:
                zip_content = response.read()
            
            print("Extracting and batching documents from zip...")
            batch_docs = []
            batch_metas = []
            batch_ids = []
            
            with zipfile.ZipFile(io.BytesIO(zip_content)) as z:
                for file_info in z.infolist():
                    if file_info.filename.endswith('.md'):
                        content = z.read(file_info.filename).decode('utf-8')
                        
                        if file_info.filename.endswith('index.md'):
                            url_path = file_info.filename[:-8]
                        else:
                            url_path = file_info.filename[:-3]
                            
                        if url_path.endswith('/'):
                            url_path = url_path[:-1]
                            
                        url = f"https://www.elastic.co/docs/{url_path}"
                        if url.endswith('/'):
                            url = url[:-1]
                        
                        if url not in visited:
                            batch_docs.append(content)
                            batch_metas.append({"source": url})
                            batch_ids.append(url)
                            visited.add(url)
                            
                            if len(batch_docs) >= 100:
                                collection.upsert(
                                    documents=batch_docs,
                                    metadatas=batch_metas,
                                    ids=batch_ids
                                )
                                batch_docs = []
                                batch_metas = []
                                batch_ids = []
                                
                if batch_docs:
                    collection.upsert(
                        documents=batch_docs,
                        metadatas=batch_metas,
                        ids=batch_ids
                    )
            results_summary.append(f"✅ Indexed {len(visited)} documents from {zip_url}")
            print(f"Finished processing {len(visited)} documents from llm.zip")
        except Exception as e:
            print(f"Failed to process llm.zip: {e}")
            results_summary.append(f"❌ Failed to process zip: {e}")

    # Process the zip file first in a separate thread to avoid blocking
    await asyncio.to_thread(fetch_and_process_zip)

    async with AsyncWebCrawler() as crawler:
        while queue:
            current_url = queue.popleft()
            
            # Strip fragment (e.g., #section) to avoid duplicate crawling
            current_url, _ = urldefrag(current_url)
            if current_url.endswith('/'):
                current_url = current_url[:-1]
            
            if current_url in visited:
                continue
                
            visited.add(current_url)
            print(f"Indexing: {current_url}")
            
            # arun() fetches and converts to LLM-friendly Markdown automatically
            result = await crawler.arun(url=current_url)

            if result.success:
                # Upsert into vector store
                # We use the URL as the ID to avoid duplicate entries
                collection.upsert(
                    documents=[result.markdown],
                    metadatas=[{"source": current_url}],
                    ids=[current_url]
                )
                results_summary.append(f"✅ Indexed: {current_url}")
                
                # Recursively add internal links under the configured seed sites
                internal_links = result.links.get("internal", [])
                for link_obj in internal_links:
                    href = link_obj.get("href")
                    if href:
                        href_clean, _ = urldefrag(href)
                        if href_clean.endswith('/'):
                            href_clean = href_clean[:-1]
                        # Ensure the link is within one of the root seed sites
                        if any(href_clean.startswith(seed) for seed in seed_sites):
                            if href_clean not in visited and href_clean not in queue:
                                queue.append(href_clean)
            else:
                results_summary.append(f"❌ Failed: {current_url} ({result.error_message})")
                
            # Throttle requests to be polite to the target server and local CPU
            if queue:
                await asyncio.sleep(crawl_delay)

    summary = "\\n".join(results_summary)
    print(f"Indexing complete:\\n{summary}")
    return summary"""

if old_code in content:
    with open("server.py", "w") as f:
        f.write(content.replace(old_code, new_code))
    print("   ✅ Successfully patched server.py to use llm.zip")
else:
    print("   ⚠️  Could not find the target code block to patch in server.py.")
PATCHEOF
    cd mcp-server
    python3 patch_server.py
    rm patch_server.py
    cd ..

    echo "   Configuring Elastic documentation sites from mcp-docs.env..."
    cp mcp-docs.env mcp-server/.env
    
    cd mcp-server
    # Update docker-compose.yml to read DOC_SITES from the .env file
    sed -i.bak 's|- DOC_SITES=.*|- DOC_SITES=${DOC_SITES}|' docker-compose.yml

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

