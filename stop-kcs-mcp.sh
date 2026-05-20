#!/bin/bash
# stop-kcs-mcp.sh — Stop the KCS MCP server
PORT=8001

if [ -f /tmp/kcs-mcp.pid ]; then
    PID=$(cat /tmp/kcs-mcp.pid)
    if kill "${PID}" 2>/dev/null; then
        echo "KCS MCP server stopped (PID ${PID})."
    else
        echo "Process ${PID} not found; may have already stopped."
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
