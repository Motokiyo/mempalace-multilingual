#!/bin/bash
# install.sh — Patch MemPalace for multilingual embeddings (BGE-M3 via Ollama)
#
# Usage: ./install.sh
#
# Prerequisites:
#   pip install mempalace
#   brew install ollama (or see https://ollama.com)
#   ollama pull bge-m3

set -e

echo "=== MemPalace Multilingual Patch ==="
echo ""

# Check mempalace installed
MEMPALACE_DIR=$(python3 -c "import mempalace; import os; print(os.path.dirname(mempalace.__file__))" 2>/dev/null)
if [ -z "$MEMPALACE_DIR" ]; then
    echo "ERROR: mempalace not installed. Run: pip install mempalace"
    exit 1
fi
echo "MemPalace found at: $MEMPALACE_DIR"

# Check Ollama running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "WARNING: Ollama not running. Start it with: ollama serve"
    echo "         The patch will fall back to English-only embeddings until Ollama is available."
fi

# Check BGE-M3
if ollama list 2>/dev/null | grep -q "bge-m3"; then
    echo "BGE-M3 model: OK"
else
    echo "BGE-M3 not found. Downloading (~1.2 GB)..."
    ollama pull bge-m3
fi

# Copy embedding module
cp ollama_embedding.py "$MEMPALACE_DIR/"
echo "Installed: ollama_embedding.py"

# Patch miner.py
if grep -q "_get_embedding_fn" "$MEMPALACE_DIR/miner.py"; then
    echo "miner.py: already patched"
else
    # Backup
    cp "$MEMPALACE_DIR/miner.py" "$MEMPALACE_DIR/miner.py.bak"

    # Inject _get_embedding_fn before get_collection
    python3 -c "
import re
with open('$MEMPALACE_DIR/miner.py', 'r') as f:
    content = f.read()

# Add the embedding function
embed_fn = '''
def _get_embedding_fn():
    \"\"\"Use Ollama BGE-M3 (multilingual) if available, else ChromaDB default.\"\"\"
    try:
        from mempalace.ollama_embedding import OllamaEmbeddingFunction
        import requests
        requests.get(\"http://localhost:11434/api/tags\", timeout=2)
        return OllamaEmbeddingFunction(model=\"bge-m3\")
    except Exception:
        return None  # ChromaDB default (MiniLM-L6)


'''

# Insert before get_collection
content = content.replace(
    'def get_collection(palace_path: str):',
    embed_fn + 'def get_collection(palace_path: str):'
)

# Replace get_collection body
content = content.replace(
    '''    client = chromadb.PersistentClient(path=palace_path)
    try:
        return client.get_collection(\"mempalace_drawers\")
    except Exception:
        return client.create_collection(\"mempalace_drawers\")''',
    '''    client = chromadb.PersistentClient(path=palace_path)
    ef = _get_embedding_fn()
    try:
        return client.get_collection(\"mempalace_drawers\", embedding_function=ef)
    except Exception:
        return client.create_collection(\"mempalace_drawers\", embedding_function=ef)'''
)

with open('$MEMPALACE_DIR/miner.py', 'w') as f:
    f.write(content)
"
    echo "Patched: miner.py (backup: miner.py.bak)"
fi

# Patch searcher.py
if grep -q "_get_embedding_fn" "$MEMPALACE_DIR/searcher.py"; then
    echo "searcher.py: already patched"
else
    cp "$MEMPALACE_DIR/searcher.py" "$MEMPALACE_DIR/searcher.py.bak"

    python3 -c "
with open('$MEMPALACE_DIR/searcher.py', 'r') as f:
    content = f.read()

# Add import after chromadb import
embed_fn = '''

def _get_embedding_fn():
    \"\"\"Use Ollama BGE-M3 (multilingual) if available, else ChromaDB default.\"\"\"
    try:
        from mempalace.ollama_embedding import OllamaEmbeddingFunction
        import requests
        requests.get(\"http://localhost:11434/api/tags\", timeout=2)
        return OllamaEmbeddingFunction(model=\"bge-m3\")
    except Exception:
        return None

'''

content = content.replace(
    'import chromadb\n\n\ndef search',
    'import chromadb\n' + embed_fn + '\ndef search'
)

# Replace all get_collection calls
content = content.replace(
    'col = client.get_collection(\"mempalace_drawers\")',
    'ef = _get_embedding_fn()\\n        col = client.get_collection(\"mempalace_drawers\", embedding_function=ef)'
)

with open('$MEMPALACE_DIR/searcher.py', 'w') as f:
    f.write(content)
"
    echo "Patched: searcher.py (backup: searcher.py.bak)"
fi

echo ""
echo "=== Done ==="
echo ""
echo "IMPORTANT: You must purge and re-mine your palace (old embeddings are incompatible):"
echo ""
echo "  python3 -c \"import chromadb; c=chromadb.PersistentClient(path='\$HOME/.mempalace/palace'); c.delete_collection('mempalace_drawers'); print('Purged.')\""
echo "  mempalace mine ."
echo ""
echo "Re-mining will take 30-45 min on ~1500 files (M1 Max)."
