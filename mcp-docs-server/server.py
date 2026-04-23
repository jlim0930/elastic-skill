import os
import asyncio
from typing import List
from fastmcp import FastMCP
from crawl4ai import AsyncWebCrawler
import chromadb

# 1. Initialize FastMCP with HTTP transport
# We use host 0.0.0.0 so it is accessible outside the Docker container
mcp = FastMCP("RemoteDocIndexer")

# 2. Setup ChromaDB (Local & Persistent)
# By default, ChromaDB uses 'all-MiniLM-L6-v2' embeddings locally.
# No API keys are required for this setup.
DB_PATH = "./chroma_db"
client = chromadb.PersistentClient(path=DB_PATH)
collection = client.get_or_create_collection(name="documentation_store")

def get_target_sites() -> List[str]:
    """Helper to parse DOC_SITES from environment variables."""
    sites_str = os.getenv("DOC_SITES", "")
    if not sites_str:
        return []
    return [s.strip() for s in sites_str.split(",") if s.strip()]

@mcp.tool()
async def index_configured_sites():
    """
    Crawls the sites defined in the DOC_SITES env var and
    stores them in the local vector database.
    """
    sites = get_target_sites()
    if not sites:
        return "Error: No sites found in DOC_SITES environment variable."

    results_summary = []

    async with AsyncWebCrawler() as crawler:
        for site in sites:
            print(f"Indexing: {site}")
            # arun() fetches and converts to LLM-friendly Markdown automatically
            result = await crawler.arun(url=site)

            if result.success:
                # Upsert into vector store
                # We use the URL as the ID to avoid duplicate entries
                collection.upsert(
                    documents=[result.markdown],
                    metadatas=[{"source": site}],
                    ids=[site]
                )
                results_summary.append(f"✅ Indexed: {site}")
            else:
                results_summary.append(f"❌ Failed: {site} ({result.error_message})")

    return "\n".join(results_summary)

@mcp.tool()
async def search_docs(query: str):
    """
    Searches the local vector store for documentation snippets
    relevant to the user's query.
    """
    # Query the top 3 most relevant sections
    results = collection.query(
        query_texts=[query],
        n_results=3
    )

    if not results["documents"] or not results["documents"][0]:
        return "No relevant documentation found. Try indexing the sites first."

    # Format the output for the LLM
    output = "Found the following relevant information:\n"
    for doc, metadata in zip(results["documents"][0], results["metadatas"][0]):
        output += f"\n--- Source: {metadata['source']} ---\n{doc[:2000]}...\n"

    return output

if __name__ == "__main__":
    import sys
    # If "sse" is passed as an argument, run with SSE transport
    if len(sys.argv) > 1 and sys.argv[1] == "sse":
        mcp.run(transport="sse", host="0.0.0.0", port=8000)
    else:
        # Default to stdio for "docker run" compatibility
        mcp.run()
