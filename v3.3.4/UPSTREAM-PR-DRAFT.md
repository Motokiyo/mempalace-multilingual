# Upstream — état des lieux 10/05/2026

**Repo** : https://github.com/MemPalace/mempalace (default branch `develop`)
**Latest tag** : v3.3.4 (01/05/2026), v3.3.5 en cours de release (PR #1432 mergée)

## Découverte importante

Une PR existe déjà depuis le 17/04 et n'est pas encore mergée :

- **PR #982** — `feat(embeddings): opt-in Ollama embedding backend for GPU acceleration` par @felipetruman
- **État** : OPEN, 3 commenteurs (felipetruman, Qodo-Free-For-OSS, igorls), pas encore review-approved
- **Approche** : env var `EMBEDDING_PROVIDER=ollama`, `OllamaEmbeddingFunction` de chromadb, défauts `nomic-embed-text` / 60s timeout
- **Différence avec notre patch** :
  - Modifie `backends/chroma.py` (vs notre `embedding.py` — plus propre selon l'archi 3.3.4)
  - Default model : `nomic-embed-text` (768d, biais anglais) — **pas multilingue**
  - Pas de cas d'usage FR documenté

→ **Conclusion** : ne pas soumettre une PR concurrente. Plutôt **commenter sur #982** pour pousser la maintenance à merger, en apportant l'angle multilingue.

## Brouillon de commentaire à poster sur #982

> **+1 from a heavy multilingual user** — landing this would close a real gap.
>
> I've been monkey-patching the same hook locally since v3.0.0 (FR/EN corpus, 68k drawers). The architectural cleanup in 3.3.4 (`embedding.py` factory, `backends/chroma.py` wrapper) made my patch trivial — 17 lines, one file. This PR is essentially the same idea applied at the backend layer.
>
> One suggestion: consider documenting `bge-m3` as the recommended model for non-English corpora, or even shipping it as an alternate default. `nomic-embed-text` (768d, English bias) gives near-random semantic ranking on French/Korean/Japanese content. `bge-m3` (1024d, 100+ langs, BAAI) restores meaningful similarity scores — I see queries like *"détection de chute pour personnes âgées EHPAD"* correctly returning `fall_detector.py` as the top hit, which MiniLM/nomic both rank deep in the noise.
>
> Tested today against v3.3.4 + this PR's approach (re-implemented locally as a `mempalace/embedding.py` hook, since I can't easily run a development checkout side-by-side with my pip install). Hybrid BM25 + cosine search (also new in 3.3.0, great work!) further compensates for embedding model choice — but exact-name retrieval alone isn't a substitute for proper multilingual semantic similarity.
>
> Happy to share concrete metrics on a 68k-drawer FR/EN palace (latency, recall@k, hybrid score distributions) if it would help reviewers, just ping me.

## Brouillon PR autonome (fallback si #982 stagne 30+ jours de plus)

**Title** : `feat(embedding): pluggable Ollama backend wired through embedding.py factory`

**Why a separate PR** : #982 modifies `backends/chroma.py`. The 3.3.4 refactor introduced `mempalace/embedding.py` as the **single factory** for embedding functions (used by `_resolve_embedding_function()` in `chroma.py`). Wiring Ollama at the factory level keeps the cleanup pattern intact and makes the env var equally applicable to any future backend (LanceDB, future swap of the chroma backend itself).

**Diff** : 17 lines added to `mempalace/embedding.py` (see `embedding-ollama-hook.patch` next door).

**Body** (cf. version précédente de ce fichier).

## Ce qu'on fait, concrètement

1. **Aujourd'hui** : patch local appliqué sur Mac + sauvé dans ce dossier. MCP `~/.claude.json` patché. Hetzner à faire.
2. **Demain ou après-demain** : Alex valide → on poste le **commentaire** sur PR #982 sous compte Motokiyo.
3. **Si #982 merge dans la prochaine release** : on retire notre patch local, on garde juste les env vars (renommer `MEMPALACE_EMBEDDING_BACKEND` → `EMBEDDING_PROVIDER`, `MEMPALACE_OLLAMA_MODEL` → `OLLAMA_EMBED_MODEL`).
4. **Si #982 stagne 30+ jours après notre commentaire** : on soumet la PR autonome (alternative architecture via `embedding.py`).

## Branche locale prête

Une branche `feat/embedding-ollama-backend` existe dans `/tmp/mempalace-fork/` (clone du fork `Motokiyo/mempalace` synchro avec `upstream/develop`). Pas pushée. À reprendre si décision PR autonome.
