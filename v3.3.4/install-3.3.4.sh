#!/bin/bash
# install-3.3.4.sh — Multilingual hook for MemPalace v3.3.4+
#
# Activates ollama_embedding.OllamaEmbeddingFunction (BGE-M3, 100+ langs, 1024 dims)
# via env var MEMPALACE_EMBEDDING_BACKEND=ollama. Replaces the historical
# 3-file monkey-patch (miner.py + searcher.py + mcp_server.py) with a single
# 17-line hook in mempalace/embedding.py.
#
# Prerequisites:
#   pip install mempalace>=3.3.4
#   ollama serve
#   ollama pull bge-m3
#
# Usage:
#   ./install-3.3.4.sh
#   export MEMPALACE_EMBEDDING_BACKEND=ollama       # in shell rc
#   # or set in ~/.claude.json mcpServers.mempalace.env

set -e

MEMPALACE_DIR=$(python3 -c "import mempalace, os; print(os.path.dirname(mempalace.__file__))")
[ -z "$MEMPALACE_DIR" ] && { echo "ERROR: mempalace not installed"; exit 1; }
echo "MemPalace at: $MEMPALACE_DIR"
echo "Version: $(pip show mempalace | grep -i ^version)"

if grep -q "MEMPALACE_EMBEDDING_BACKEND" "$MEMPALACE_DIR/embedding.py"; then
    echo "embedding.py already patched."
else
    cp "$MEMPALACE_DIR/embedding.py" "$MEMPALACE_DIR/embedding.py.bak-pre-ollama"
    patch "$MEMPALACE_DIR/embedding.py" < "$(dirname "$0")/embedding-ollama-hook.patch"
    echo "embedding.py patched (backup: embedding.py.bak-pre-ollama)"
fi

# ollama_embedding.py shipped natively since 3.3.x — verify presence
[ -f "$MEMPALACE_DIR/ollama_embedding.py" ] || cp "$(dirname "$0")/../ollama_embedding.py" "$MEMPALACE_DIR/"

if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "WARN: Ollama not running. Start: ollama serve"
fi
ollama list 2>/dev/null | grep -q bge-m3 || { echo "Pulling bge-m3 (~1.2 GB)..."; ollama pull bge-m3; }

echo ""
echo "Done. Activate with:"
echo "  export MEMPALACE_EMBEDDING_BACKEND=ollama"
echo "  # or set env in ~/.claude.json MCP server config"
