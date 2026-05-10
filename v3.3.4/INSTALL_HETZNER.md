# Procédure upgrade Hermes/Hetzner vers MemPalace 3.3.4

À exécuter quand tu valides (J+1 ou J+2 après que la version Mac tient sans souci).

## Pré‑requis

- Service systemd `hermes-gateway-precepteur` en route, PID stable.
- SSH `ssh openclaw` opérationnel (clé id_ed25519_github présente).
- Ollama serveur tourne déjà sur Hetzner (déjà installé pour `bge-m3` selon notre KG).

## Étapes (à dérouler dans cet ordre)

### 1. Backup palace + venv (en SSH)

```bash
ssh openclaw bash -c "'
TS=\$(date +%Y%m%d-%H%M%S)
cp -a /root/.mempalace/palace /root/.mempalace/palace.backup-pre-3.3.4-\$TS
SP=\$(/root/hermes-test/.venv/bin/python -c \"import mempalace, os; print(os.path.dirname(mempalace.__file__))\")
cp -a \$SP \$SP.backup-pre-3.3.4-\$TS
echo Backups OK in /root/.mempalace/ and \$SP
du -sh /root/.mempalace/palace.backup-pre-3.3.4-\$TS \$SP.backup-pre-3.3.4-\$TS
'"
```

### 2. Stop gateway (sinon le venv en cours d'usage casse)

```bash
ssh openclaw "systemctl stop hermes-gateway-precepteur && echo stopped"
```

### 3. pip upgrade

```bash
ssh openclaw "/root/hermes-test/.venv/bin/pip install --upgrade 'mempalace==3.3.4' 2>&1 | tail -8"
```

### 4. Réappliquer le patch BGE‑M3 (push notre fichier patch puis appliquer)

```bash
# Push le patch via scp depuis Mac
scp /Users/alexandre/Galaad-Motokiyo-Ferran/RD/Eiffel/mempalace-multilingual/app/v3.3.4/embedding-ollama-hook.patch openclaw:/tmp/

# Appliquer côté Hetzner
ssh openclaw bash -c "'
SP=\$(/root/hermes-test/.venv/bin/python -c \"import mempalace, os; print(os.path.dirname(mempalace.__file__))\")
cp \$SP/embedding.py \$SP/embedding.py.bak-pre-ollama
patch \$SP/embedding.py < /tmp/embedding-ollama-hook.patch
grep -q MEMPALACE_EMBEDDING_BACKEND \$SP/embedding.py && echo PATCH OK || echo PATCH FAIL
'"
```

### 5. Vérifier Ollama dispo + bge‑m3 présent

```bash
ssh openclaw "curl -s http://localhost:11434/api/tags | python3 -c 'import json,sys; print([m[\"name\"] for m in json.load(sys.stdin)[\"models\"]])'"
# Si bge-m3 absent : ssh openclaw "ollama pull bge-m3"
```

### 6. Activer env vars dans le service systemd

```bash
ssh openclaw bash -c "'
F=/etc/systemd/system/hermes-gateway-precepteur.service
grep -q MEMPALACE_EMBEDDING_BACKEND \$F || sed -i \"/^\[Service\]/a Environment=MEMPALACE_EMBEDDING_BACKEND=ollama\nEnvironment=MEMPALACE_OLLAMA_MODEL=bge-m3\" \$F
systemctl daemon-reload
grep MEMPAL \$F
'"
```

### 7. Test palace lecture (avant de relancer le service)

```bash
ssh openclaw "MEMPALACE_EMBEDDING_BACKEND=ollama MEMPALACE_OLLAMA_MODEL=bge-m3 /root/hermes-test/.venv/bin/python -c '
from mempalace.searcher import search
r = search(query=\"DeepSeek Hermes stack\", palace_path=\"/root/.mempalace/palace\", n_results=2)
print(\"OK:\", len(r) if r else 0, \"results\")
for x in (r or [])[:1]: print(str(x)[:300])
'"
```

### 8. Relancer le gateway

```bash
ssh openclaw "systemctl start hermes-gateway-precepteur && sleep 3 && systemctl status hermes-gateway-precepteur --no-pager | head -20"
```

### 9. Vérifier logs gateway 30 sec après démarrage

```bash
ssh openclaw "journalctl -u hermes-gateway-precepteur --since '1 minute ago' --no-pager | head -40"
# Chercher toute trace embedding/ollama/error
```

### 10. Test Telegram → Hermes → MemPalace search via outil

Demander à Hermes via Telegram : **« cherche dans la mémoire ce qu'on a décidé sur Reachy Care »**. Vérifier que :
- pas de timeout
- résultats FR pertinents (pas du bruit anglais)
- temps de réponse normal (≤ 8 s)

## Rollback en 30 secondes

```bash
ssh openclaw bash -c "'
TS_BACKUP=20260511-XXXXXX  # remplir avec le timestamp réel du backup
SP=\$(/root/hermes-test/.venv/bin/python -c \"import mempalace, os; print(os.path.dirname(mempalace.__file__))\")
systemctl stop hermes-gateway-precepteur
rm -rf \$SP
mv \$SP.backup-pre-3.3.4-\$TS_BACKUP \$SP
rm -rf /root/.mempalace/palace
mv /root/.mempalace/palace.backup-pre-3.3.4-\$TS_BACKUP /root/.mempalace/palace
systemctl start hermes-gateway-precepteur
'"
```

## Différences avec la procédure Mac

- Mac : `pip3` global pyenv. Hetzner : venv `/root/hermes-test/.venv/bin/pip`.
- Mac : `~/.claude.json` mcpServers. Hetzner : `Environment=` dans le service systemd.
- Mac : palace dans `~/.mempalace/palace`. Hetzner : `/root/.mempalace/palace` (réplica rsync depuis Mac à 04:00, mais MemPalace y écrit aussi côté Hermes — vérifier comportement après upgrade).

## ⚠️ Point d'attention rsync Mac → Hetzner

Le rsync 04:00 (`com.alexandre.mempalace-rsync-hetzner`) copie `~/.mempalace/` Mac → Hetzner avec `--delete`. Si l'upgrade Mac change le format du palace (segments HNSW, schéma SQLite), le rsync de la nuit suivante peut écraser un palace Hetzner légèrement différent (post‑repair avec nouvelle métrique cosine). Dans le doute, **vérifier compatibilité 3.3.4 ↔ 3.3.4 du palace après le `mempalace repair` lancé ce soir sur Mac**.

## Calendrier

- Mac : upgrade fait le 10/05/2026 soir, repair en cours
- Hetzner : à faire le 11 ou 12/05/2026 selon stabilité Mac observée
