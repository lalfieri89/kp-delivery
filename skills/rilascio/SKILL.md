---
name: rilascio
description: Orchestratore del rilascio pre-commit. Esegue l'intero processo "ho finito → review → commit" in automatico, con gate sui problemi critici. Invocala quando lo sviluppatore segnala di aver finito le modifiche e vuole procedere — frasi tipo "ok fatto, possiamo committare", "pronto per il commit", "ho finito, committa e pusha", "facciamo commit e push", oltre al comando esplicito /rilascio. Lancia code-reviewer, si ferma se ci sono critici, altrimenti chiede conferma e lancia commit-push-pr.
version: 1.1.0
argument-hint: "[branch-destinazione opzionale] [--skip-tests]"
allowed-tools: Agent, Read, Grep, Glob, Bash, Skill
---

Sei l'orchestratore del rilascio. Coordini due componenti esistenti **senza duplicarne la logica**: l'agente `code-reviewer` (review pre-commit stack-aware) e la skill `commit-push-pr` (commit, push, PR). Il tuo valore aggiunto è il **gate automatico sui critici** e l'unico punto d'ingresso.

Branch di destinazione (se indicato in `$ARGUMENTS`): passalo a `commit-push-pr` in FASE 3. Se è presente `--skip-tests`, passalo a `code-reviewer`.

---

## FASE 1 — Review pre-commit

Lancia l'agente **`code-reviewer`** (senza modificare nulla): rileva lo stack del progetto e analizza in parallelo tutti i file modificati, producendo il report consolidato in `.claude/review/`.

- Se è presente `--skip-tests`, avvia `code-reviewer --skip-tests`.
- Attendi il completamento dell'agente prima di procedere.

---

## FASE 2 — Gate sui problemi critici

Leggi il report appena prodotto (il più recente in `.claude/review/`, tipicamente `.claude/review/[YYYY-MM-DD]-consolidato-review.md`) e conta i problemi di livello **CRITICO** / la sezione **BLOCCANTI**.

**Se in `.claude/review/` non esiste un report odierno** (l'agente è fallito o non ha prodotto nulla) → **fermati e segnala** che la review non è disponibile; non procedere al commit.

### Caso A — Ci sono CRITICI → **FERMATI, e offri di risolverli**

Non procedere al commit. Presenta:

```
🔴 Rilascio bloccato — N problema/i CRITICO/I da risolvere prima del commit:

[elenco sintetico dei bloccanti: file · riga · problema]

Li sistemo io adesso? (sì, sistemali / li guardo prima io)
```

**Prima di presentarli, verifica che siano passati dal verifier** di `code-reviewer` FASE 1bis: il
report deve avere la riga `Critici verificati: N confermati · M declassati`. Se quella riga manca,
l'agente ha saltato la verifica e stai per bloccare il rilascio su rilievi mai controllati: **non
presentarli come bloccanti**, rilancia prima la verifica sui soli critici, poi torna qui.

**Riporta sempre in chat la tabella di riepilogo del report** (critici / attenzioni / info per stack,
con il verdict) e una riga che dica se vale la pena aprire il file. Non lasciare all'utente il compito
di aprirlo per sapere cosa c'è dentro.

Se l'utente accetta, lancia `coder` sui soli critici confermati, un giro, con il vincolo di restare
dentro il perimetro della modifica: un critico che nasce da **codice preesistente** non si corregge
riscrivendo quel codice — si corregge nel percorso nuovo, o si segnala come debito senza toccarlo.
Al termine **rilancia la review** (con l'istruzione di ignorare il report esistente) e ripassa dal
gate: non dare per risolto ciò che non è stato riverificato.

Se l'utente preferisce guardarli prima, termina qui. **Non chiamare `commit-push-pr` in nessuno dei
due casi** finché i critici non risultano risolti da una review fresca.

### Caso B — Nessun CRITICO → chiedi conferma

Presenta il riepilogo verde e **attendi l'OK esplicito dell'utente**:

```
✅ Review OK — nessun problema critico.
   Attenzioni: N · Info: N
   Stack analizzato: <Java / Angular / React / misto>

[tabella di riepilogo del report: critici / attenzioni / info per stack, con il verdict]

📄 <"Apri .claude/review/[data]-consolidato-review.md: contiene ..." oppure
    "Report in .claude/review/[data]-consolidato-review.md — nulla che richieda la tua lettura.">

Pronto per il commit. Procedo? (dammi l'ok / sì)
```

**Non eseguire alcuna operazione git finché l'utente non conferma.** Se l'utente dice no, fermati.

---

## FASE 3 — Commit, push e PR

Solo dopo l'OK esplicito, invoca la skill **`commit-push-pr`** con la Skill tool, passandole l'eventuale branch di destinazione ricevuto in `$ARGUMENTS`. Tutti i guardrail (branch corrente, conferma separata su commit e su push, niente improvvisazione) e le tre pause vivono in quella skill: non replicarli qui.

Il gate sui critici di FASE 2 è una rete di sicurezza **aggiuntiva** rispetto a quella che `commit-push-pr` FASE 0 esegue comunque su se stessa: la ridondanza è voluta.

---

## Regole importanti

- **Mai committare/pushare senza l'OK esplicito dell'utente** (FASE 2 Caso B). Il gate sui critici e la conferma sono obbligatori.
- **Tu** non modifichi i file sorgente: la review è di sola lettura. Le uniche modifiche ammesse in questa skill sono quelle dei critici confermati (FASE 2 Caso A) e le fa `coder`, su richiesta esplicita dell'utente — mai tu di tua iniziativa, e mai senza aver chiesto. Le modifiche ai test le fanno gli agenti di test.
- **Riporta sempre in chat la tabella di riepilogo** e di' se il report va aperto o no. Un riepilogo che vive solo nel file è come non averlo prodotto: l'utente non deve aprire un file per sapere se deve aprirlo.
- Non duplicare la logica di review o di commit: orchestri soltanto `code-reviewer` e `commit-push-pr`.
- Se non risulta alcun file modificato (`git diff --name-only HEAD` vuoto), comunicalo e fermati: non c'è nulla da rilasciare.
- Se esiste già un report di oggi, `code-reviewer` lo riusa per default (è un agente isolato, non può chiedere conferma). Se serve una review aggiornata (es. hai fatto altre modifiche dopo l'ultimo report), dillo esplicitamente nel prompt con cui lanci `code-reviewer` ("ignora il report esistente, rilancia l'analisi completa").
