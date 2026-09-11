---
name: commit-push-pr
description: Gestisce commit, push e creazione PR opzionale per qualsiasi progetto (Backend Java o Frontend Angular/React). Genera il messaggio in formato Conventional Commits, chiede conferma prima di ogni operazione git distruttiva, e al termine chiede se creare la PR. Usare dopo code-reviewer o direttamente per qualsiasi branch.
version: 1.3.0
argument-hint: "[branch-destinazione] [--no-push] [--draft-pr] [--squash]"
allowed-tools: Bash, Read, Glob, Grep
---

> **Nota — invocazione.** Questa skill si attiva digitando `/commit-push-pr`, oppure viene invocata tramite la Skill tool da `rilascio` (FASE 3) e da `sviluppa`. I guardrail e le tre pause con conferma esplicita restano identici in entrambi i casi: è il meccanismo di sicurezza, non l'invocazione manuale, a garantirli.

**Branch di destinazione**: $ARGUMENTS (default: `main` se non specificato)

**Flag supportati**:
- `--no-push`: Esegui commit ma non fare push
- `--draft-pr`: Crea la PR come bozza
- `--squash`: Proponi squash dei commit prima del push

---

## 🛑 GUARDRAIL — vincoli invalicabili (mai violare, per nessun motivo)

1. **Branch corrente, sempre.** Committa **sul branch su cui ti trovi**. **MAI** `git checkout -b`, `git branch`, `git switch -c` o creare/cambiare branch. Se il branch corrente è `main` / `master` / `develop`, **FERMATI e chiedi all'utente** prima di committare — non creare un branch da solo. Il "branch di destinazione" sopra è solo il `--base` della PR, **non** un branch da creare per il commit.
2. **Push solo con conferma separata.** **MAI** `git push` senza la conferma esplicita della Pausa 2, mostrata DOPO i commit da pushare. Un "ok" al commit **non** autorizza il push.
3. **Nessuna pausa è opzionale.** Pausa 1 (commit) e Pausa 2 (push) sono obbligatorie. Se sei in dubbio su qualcosa, **fermati e chiedi** — non improvvisare.

---

## FASE 0 — Controllo review pendenti

Individua il report più recente con il tool **Glob** su `.claude/review/*-review.md` (i nomi sono `[YYYY-MM-DD]-consolidato-review.md` per l'orchestrato o `[YYYY-MM-DD]-<NomeClasse>-review.md` per lo standalone: l'ordinamento alfabetico coincide con quello cronologico, prendi l'ultimo). Se non trovi nulla → procedi direttamente alla FASE 1.

Leggi il report più recente con **Read**. In testa deve avere uno stamp:
```
Data: [YYYY-MM-DD]
Branch: [branch]
Commit base: [sha]
File analizzati: [elenco]
```

In **una sola** chiamata Bash (lo stato della shell non persiste fra chiamate separate, quindi tutto il confronto va fatto in questa unica invocazione):

```bash
git rev-parse HEAD
git diff --name-only HEAD
```

Confronta l'output con lo stamp del report:
- se lo `sha` di `git rev-parse HEAD` **coincide** con `Commit base` del report, e nessun file in `git diff --name-only HEAD` è assente da `File analizzati` → il report riflette lo stato attuale.
- altrimenti → il report è **obsoleto** (ci sono commit o modifiche successive alla sua generazione).

Poi cerca nel report la sezione `BLOCCANTI` o righe con `CRITICO` / `CRITICAL` (case-insensitive — il report può essere in italiano o inglese).

**Se NON ci sono critici** → procedi alla FASE 1.

**Se ci sono critici e il report è obsoleto** (per il confronto sopra) → il report non riflette lo stato attuale. **Non bloccare sui critici.** Avvisa:

  > ⚠️ **Report obsoleto.** La review del [data] (commit base `[sha]`) riporta N critico/i, ma il branch è stato modificato dopo la review:
  > - [file fuori dallo stamp "File analizzati", o commit successivi a "Commit base"]
  >
  > I critici potrebbero essere già risolti. Rilancia la review (`/rilascio` o l'agente `code-reviewer`) per generare una review aggiornata, poi riprova il commit.
  >
  > Vuoi procedere comunque senza review aggiornata? (sì/no)

  Se l'utente dice no → interrompi qui. Se dice sì → procedi alla FASE 1.

- **Se il report è ancora valido** (stesso commit base, nessun file fuori dallo stamp) → i critici sono reali. Blocca:

  > ⚠️ **Attenzione:** la review del [data] riporta N problema/i CRITICO/I ancora presenti nel codice:
  > - [lista critici]
  >
  > Procedere comunque con il commit? (sì/no)

  Se l'utente dice no → interrompi qui. Se dice sì → procedi.

---

## FASE 1 — Generazione messaggio di commit

Analizza le modifiche:
```bash
git diff --staged   # se c'è qualcosa in staging
# oppure
git diff HEAD       # se nulla è staged
```

Genera un messaggio di commit in formato **Conventional Commits**:

```
<type>(<scope>): <descrizione imperativa ≤50 caratteri>

<body: cosa e perché, righe ≤72 caratteri — solo se logica non ovvia o > 5 file>

<footer: BREAKING CHANGE: ... — solo se applicabile>
```

Tipi validi: `feat` / `fix` / `refactor` / `perf` / `test` / `docs` / `style` / `chore` / `ci` / `revert`

Regole:
- Imperativo: "add" non "added", "fix" non "fixed"
- Lingua coerente con la storia del repository (`git log --oneline -5`)
- Body obbligatorio se > 5 file modificati
- Scope = modulo/package principale toccato

---

## ⏸ Pausa 1 — Conferma commit

**STOP. Presenta all'utente:**

```
File da includere: [lista file modificati]
Messaggio proposto:

  <type>(<scope>): <descrizione>

  <body se presente>
```

**Se hai generato un body**, chiedi esplicitamente:

```
Vuoi includere il body nel commit? (s/n)
```

Attendi risposta prima di procedere. Se l'utente dice **no**, usa solo il subject.

**Non eseguire `git add` o `git commit` senza conferma esplicita.**

---

## FASE 2 — Commit

Dopo conferma utente:

```bash
git add <file modificati — NO git add -A>
git commit -m "<messaggio approvato>"
git status
git log --oneline -5
```

Controlla conflitti con branch di destinazione:
```bash
git fetch origin
git log HEAD..origin/<target-branch> --oneline
```

---

## ⏸ Pausa 2 — Conferma push

**STOP. Presenta all'utente:**

```
Branch corrente:      <nome>
Branch destinazione:  <target>
Commit da pushare:    N
Conflitti rilevati:   sì / no

[lista commit che verranno pushati]
```

Se `--no-push` è attivo: comunica che il push è stato saltato e termina qui.

**Non eseguire `git push` senza conferma esplicita.**

---

## FASE 3 — Push

Dopo conferma utente:

```bash
git push origin <branch-corrente>
```

Se `--squash` è attivo, proponi squash prima del push e attendi conferma.

---

## ⏸ Pausa 3 — PR opzionale

Dopo il push, chiedi all'utente:

```
Push completato.

Vuoi creare una Pull Request? (sì/no)
Branch destinazione (default: main): 
```

Se l'utente dice no → termina.

---

## FASE 4 — Creazione PR (solo se richiesta)

Raccogli le informazioni per la descrizione:
```bash
git log origin/<target>..HEAD --oneline
```

Genera la descrizione PR:
- Riepilogo delle modifiche (cosa e perché)
- Breaking change se presenti
- Checklist revisori

```bash
gh pr create --title "<type>(<scope>): <descrizione>" --body "<descrizione generata>" --base <target-branch>
```
Aggiungi `--draft` in fondo al comando se `--draft-pr` è attivo. Scrivi il comando su **una sola riga**: la continuazione con `\` non è portabile su tutte le shell.

---

## Regole importanti

- `git add` sempre su file specifici — mai `git add -A` o `git add .`
- Non eseguire operazioni git distruttive (reset --hard, force push) senza conferma esplicita
- Se un file di build/dipendenze è tra i file modificati (`pom.xml`, `build.gradle`, `package.json`, `package-lock.json`), segnalarlo nel messaggio di commit e nella PR — impatta l'intero team
