import sys
import os

def patch():
    server_path = "mcp-server/server.py"
    if not os.path.exists(server_path):
        print(f"❌ Could not find {server_path}")
        sys.exit(1)

    with open(server_path, "r") as f:
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
        with open(server_path, "w") as f:
            f.write(content.replace(old_code, new_code))
        print("   ✅ Successfully patched server.py to use llm.zip")
    else:
        # Check if it's already patched
        if "llm.zip" in content:
             print("   ✅ server.py is already patched.")
        else:
            print("   ⚠️  Could not find the target code block to patch in server.py.")

if __name__ == "__main__":
    patch()
