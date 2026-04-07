"""
ollama_embedding.py — Multilingual embedding via Ollama (BGE-M3).

Replaces ChromaDB's default English-only MiniLM-L6 with a model
that understands French, English, and 100+ languages.
"""

import requests
import chromadb.api.types as types


class OllamaEmbeddingFunction(types.EmbeddingFunction):
    """ChromaDB-compatible embedding function using Ollama."""

    def __init__(self, model: str = "bge-m3", base_url: str = "http://localhost:11434"):
        self.model = model
        self.base_url = base_url

    def __call__(self, input: list[str]) -> list[list[float]]:
        embeddings = []
        for text in input:
            resp = requests.post(
                f"{self.base_url}/api/embed",
                json={"model": self.model, "input": text},
                timeout=30,
            )
            resp.raise_for_status()
            data = resp.json()
            embeddings.append(data["embeddings"][0])
        return embeddings
