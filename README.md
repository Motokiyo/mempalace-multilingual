# MemPalace Multilingual Patch

Patch pour [MemPalace](https://github.com/milla-jovovich/mempalace) qui remplace le modèle d'embeddings par défaut (MiniLM-L6, anglais uniquement) par **BGE-M3** via Ollama (100+ langues dont le français).

## Le problème

MemPalace v3.0.0 utilise ChromaDB avec son embedding par défaut : `all-MiniLM-L6-v2`. Ce modèle est entraîné principalement sur de l'anglais. Résultat : les recherches sémantiques sur du contenu français retournent des résultats non pertinents (scores négatifs, mauvaise correspondance).

## La solution

On remplace l'embedding par **BGE-M3** (BAAI), un modèle multilingue de 1.2 Go qui comprend 100+ langues. Il tourne en local via Ollama, sans envoi de données au cloud.

| | Avant (MiniLM-L6) | Après (BGE-M3) |
|---|---|---|
| Langues | Anglais principalement | 100+ langues |
| Dimension | 384 | 1024 |
| Taille | 80 Mo | 1.2 Go |
| Qualité FR | Mauvaise | Excellente |
| Dépendance | Aucune (ONNX embarqué) | Ollama doit tourner |

## Installation

### Prérequis

```bash
pip install mempalace
brew install ollama   # ou voir https://ollama.com
ollama pull bge-m3
```

### Appliquer le patch

```bash
# Trouver le répertoire d'installation de mempalace
MEMPALACE_DIR=$(python3 -c "import mempalace; import os; print(os.path.dirname(mempalace.__file__))")

# Copier le module d'embedding Ollama
cp ollama_embedding.py "$MEMPALACE_DIR/"

# Appliquer les patches
patch -d "$MEMPALACE_DIR" < patches/miner.patch
patch -d "$MEMPALACE_DIR" < patches/searcher.patch
```

### Recréer la base d'embeddings

Les embeddings MiniLM-L6 (384 dimensions) sont incompatibles avec BGE-M3 (1024 dimensions). Il faut purger et re-miner :

```bash
python3 -c "
import chromadb
client = chromadb.PersistentClient(path='$HOME/.mempalace/palace')
client.delete_collection('mempalace_drawers')
print('Base purgée.')
"

# Re-miner (30-45 min sur un corpus de 1500 fichiers, M1 Max)
mempalace mine .
```

### Vérifier

```bash
# Ollama doit tourner
ollama list | grep bge-m3

# Tester une recherche en français
mempalace search "détection de chute pour personnes âgées"
```

## Comment ça marche

Le patch ajoute un fichier `ollama_embedding.py` qui implémente l'interface `EmbeddingFunction` de ChromaDB. Les fichiers `miner.py` et `searcher.py` sont modifiés pour :

1. Vérifier si Ollama tourne (GET `http://localhost:11434/api/tags`)
2. Si oui : utiliser BGE-M3 via Ollama pour les embeddings
3. Si non : fallback sur le MiniLM-L6 par défaut (compatibilité)

Le fallback garantit que MemPalace fonctionne même sans Ollama, mais avec la qualité d'origine.

## Fichiers

```
ollama_embedding.py     # Module d'embedding Ollama pour ChromaDB
patches/
  miner.patch           # Patch pour miner.py
  searcher.patch        # Patch pour searcher.py
```

## Crédits

- [MemPalace](https://github.com/milla-jovovich/mempalace) par Milla Jovovich et Ben Sigman
- [BGE-M3](https://huggingface.co/BAAI/bge-m3) par BAAI (Beijing Academy of AI)
- [Ollama](https://ollama.com) pour l'inférence locale
- Patch par Alexandre Ferran / EIFFEL AI
