---
name: doc-search
description: Cerca un termine in tutta la conoscenza salvata del workspace (.claude/review/, .claude/plan/, docs/). Invocarlo con /doc-search "termine" per trovare rapidamente report di code review, piani di sviluppo o documentazione prodotta dagli agenti.
version: 1.1.0
allowed-tools: Glob, Grep
---

Sei un motore di ricerca sulla conoscenza accumulata del progetto. Rispondi sempre in italiano.

## Cosa fare

Ricevi un termine di ricerca come argomento (es. `/doc-search "N+1"`).

### Step 1 — Identifica le cartelle disponibili

Usa Glob per verificare quali cartelle di output esistono:
- `.claude/review/*.md`
- `.claude/review/archive/*.md`
- `.claude/plan/*.md`
- `docs/*.md`

Escludi i file `INDEX.md` dalla ricerca.

### Step 2 — Cerca in ogni cartella disponibile

Per ogni cartella che esiste, usa il tool Grep per cercare il termine:
- Pattern: il termine ricevuto (case-insensitive)
- Percorso: la cartella corrispondente
- Tipo file: `.md`
- Mostra 2 righe di contesto prima e dopo ogni match

### Step 3 — Presenta i risultati

**Formato output:**

```
🔍 Ricerca: "[termine]"
Cartelle cercate: .claude/review/ · .claude/plan/ · docs/

─── .claude/review/ ───────────────────────────────
📄 .claude/review/2026-01-20-consolidato-review.md — riga 45
  ...testo precedente...
  → MATCH: riga contenente il termine
  ...testo seguente...

─── .claude/plan/ ─────────────────────────────────
Nessun risultato.

─── docs/ ─────────────────────────────────
Nessun risultato.
```

**Se non c'è nessun risultato in nessuna cartella:**
```
🔍 Ricerca: "[termine]"
Nessuna corrispondenza trovata in .claude/review/, .claude/plan/, docs/.

Suggerimenti:
- Prova un termine più generico
- Controlla che esista almeno un report in .claude/review/ o un piano in .claude/plan/
- Usa `/rilascio` (o l'agente `code-reviewer`) per generare il report del branch corrente, o `/task-planner` per generare un piano
```

**Se una cartella non esiste:** omettila silenziosamente dall'output (non mostrare errori).

## Regole

- Ricerca case-insensitive
- Mostra sempre il path relativo del file, non il path assoluto
- Se il termine ha spazi, cercalo esattamente come fornito E cerca i singoli token separatamente, mostrando i risultati distinti
- Non modificare nessun file
- Per i report in `.claude/review/archive/`, indicare esplicitamente che sono archiviati
