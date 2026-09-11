# kp-deliver — Toolkit Claude Code per Sviluppatori

Raccolta di **agenti** e **skill** per [Claude Code](https://docs.anthropic.com/it/docs/claude-code/getting-started), pensata per gli **sviluppatori** full-stack del team (Backend Java Spring Boot, Frontend Angular/React). Copre l'intero ciclo di sviluppo: pianificazione del task → implementazione per ondate di sottotask → code review → commit/push/PR.

Non è un'applicazione: è un pacchetto di configurazione che viene installato nella cartella utente `~/.claude/` (globale, valido per tutti i progetti). Gli strumenti rilevano da soli lo stack del progetto e applicano i criteri della versione effettivamente in uso.

## Cosa contiene

### Agenti (`agents/`)
Invocati automaticamente dagli orchestratori o da Claude.

| Agente | Cosa fa |
|--------|---------|
| `task-planner` | Scompone un task/requisito in sottotask verificabili (piano in `.claude/plan/`) |
| `coder` | Implementa un sottotask fino a soddisfarne il criterio di successo, in modo chirurgico |
| `code-reviewer` | Orchestratore di review pre-commit stack-aware: instrada ogni file al reviewer giusto, in parallelo |
| `java-spring-reviewer` | Code review di una classe Java Spring Boot |
| `java-test-reviewer` | Ciclo dei test di una classe Java Spring Boot |
| `fe-reviewer` | Code review di un file Frontend (Angular/React) |
| `fe-test-reviewer` | Ciclo dei test di un file Frontend (Angular/React) |

### Skill (`skills/`)
Comandi `/` invocabili dall'utente.

| Skill | Cosa fa |
|-------|---------|
| `/sviluppa <task>` | Ciclo end-to-end: piano → gate → codice+review per ondate di sottotask → gate → rilascio |
| `/task-planner <task>` | Produce il piano di sottotask verificabili |
| `/coder <ST-n o task>` | Implementa un sottotask e verifica il criterio |
| `/rilascio [branch] [--skip-tests]` | Review + gate sui critici + commit-push-pr |
| `/commit-push-pr [--no-push] [--draft-pr] [--squash]` | Commit, push e apertura PR dopo review ok |
| `/java-spring-reviewer <file>` | Review di un singolo file Backend Java |
| `/java-test-reviewer <file>` | Test di un singolo file Backend Java |
| `/fe-reviewer <file>` | Review di un singolo file Frontend |
| `/fe-test-reviewer <file>` | Test di un singolo file Frontend |
| `/init-project` | Configura il contesto di un nuovo progetto (genera il `CLAUDE.md` locale) |
| `/doc-search "termine"` | Cerca un termine in `.claude/review/` (compreso `archive/`), `.claude/plan/`, `docs/` |

### Altri file
- `CLAUDE.md` — linee guida comportamentali globali (principi KISS/YAGNI/DRY/SOLID, ruolo sviluppatore, delega agli agenti). Installato come `~/.claude/CLAUDE.md`.
- `.claude/settings.json` — tre hook: `SessionStart` carica il `CLAUDE.md` del progetto a inizio sessione, `PreToolUse` presidia il flusso di commit, `UserPromptSubmit` ricorda la *Regola sviluppo* quando il prompt chiede di scrivere o modificare codice senza aver digitato `/sviluppa`.
- `install.sh` / `install.bat` — script di installazione (macOS/Linux e Windows).

## Installazione

Da dentro la cartella del repo:

```bash
# macOS / Linux
./install.sh
```

```bat
:: Windows
install.bat
```

Lo script copia agenti, skill, `CLAUDE.md` e `settings.json` in `~/.claude/`, chiedendo conferma prima di sovrascrivere file esistenti.

## Come si usa

1. Apri Claude Code nella root di un progetto.
2. Al primo utilizzo esegui `/init-project` per generare il `CLAUDE.md` del progetto (stack, convenzioni, test, vincoli).
3. Per una nuova feature usa `/sviluppa <requisito>`: gestisce piano, implementazione, review e rilascio con tre gate umani (approvazione del piano, avvio del rilascio, ok al commit) più uno stop condizionale per ogni sottotask marcato "gate umano".

## Ciclo di sviluppo

```
/sviluppa
  └─ task-planner   → piano di sottotask in .claude/plan/   [gate: approvazione piano]
  └─ coder          → implementa gli ST-n a ondate (max 2 in parallelo)
  └─ code-reviewer  → review stack-aware in parallelo
  └─ /rilascio      → gate sui critici                       [gate: ok al commit]
        └─ commit-push-pr
```

## Conoscenza salvata tra sessioni

| Cartella / Sezione | Prodotta da | Contenuto |
|--------------------|-------------|-----------|
| `.claude/plan/` | `task-planner` | Piani di sviluppo: sottotask verificabili + INDEX |
| `.claude/review/` | `code-reviewer`, `java-spring-reviewer`, `fe-reviewer` | Report di code review per branch/file |
| `.claude/review/[data]-sviluppa-[slug].md` | `/sviluppa` | Attenzioni (rilievi non critici) raccolte nelle review per ondata, riproposte al gate del rilascio |
| `.claude/CLAUDE.md` § `## Problemi noti test` | `java-test-reviewer`, `fe-test-reviewer` | Errori di test irrisolvibili con causa e fix |

## Documentazione

Guida completa: `guida-agenti-sviluppatori.docx`.
