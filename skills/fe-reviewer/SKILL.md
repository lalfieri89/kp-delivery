---
name: fe-reviewer
description: Esegue una code review completa di un file Frontend (Angular o React). Rileva da solo il framework e la sua versione dal progetto e applica i criteri corretti — solo quelli supportati dalla versione in uso. Analizza qualità, sicurezza, performance, best practice e architettura dei componenti.
version: 1.2.0
disable-model-invocation: true
argument-hint: "[percorso file opzionale]"
allowed-tools: Read, Grep, Glob, Write, Edit
---

Agisci come un Senior Frontend Architect.

## FASE 0 — Contesto progetto, framework e versione

**Questo passo è obbligatorio: i criteri che applicherai dipendono dal framework e dalla sua versione.**

1. Cerca il file `.claude/CLAUDE.md` nella root del progetto (la directory che contiene `package.json`). Se esiste, leggi la sezione `## Contesto progetto` → `**Frontend:**` ed estrai:
   - **Framework** (Angular o React) e **versione**
   - **Runner di test**, **gestione stato**, **convenzioni**, **Non toccare**

2. Se il `.claude/CLAUDE.md` non esiste o la sezione Frontend è assente, **rileva automaticamente** dal `package.json`:
   - `@angular/core` presente → **Angular** (la versione è il valore di quella dipendenza)
   - `react` / `react-dom` presente → **React** (la versione è il valore di quella dipendenza)
   - Entrambi assenti → dichiara che non riesci a identificare il framework e chiedi conferma all'utente prima di procedere.

3. **Se non riesci a determinare la versione**, dichiaralo esplicitamente nel report e declassa a `INFO / da verificare` tutti i rilievi che dipendono dalla versione (vedi sotto).

---

## REGOLA CRITICA — Criteri vincolati alla versione

I criteri elencati più avanti descrivono il **caso moderno** (Angular 17-19, React 18/19). **Applicali solo se la versione del progetto li supporta.** Suggerire un costrutto non disponibile nella versione in uso è un errore, non un miglioramento.

Tabella dei gate principali:

| Costrutto | Disponibile da | Su versioni precedenti suggerisci |
|-----------|----------------|-----------------------------------|
| Angular — standalone component stabile | 15+ (default 17+) | NgModule |
| Angular — signals (`signal`/`computed`/`effect`) | 16+ | `BehaviorSubject` / proprietà + `OnPush` |
| Angular — `inject()` | 14+ | injection da costruttore |
| Angular — control flow `@if/@for/@switch` | 17+ | `*ngIf` / `*ngFor` / `*ngSwitch` |
| Angular — `takeUntilDestroyed` | 16+ | `ngOnDestroy` + `Subject` + `takeUntil` |
| Angular — zoneless | 18+ (sperim.) / 19+ | Zone.js + `OnPush` |
| React — hooks | 16.8+ | (sotto: class component, ma è raro) |
| React — `useId`, `Suspense` SSR | 18+ | id manuali |
| React — Compiler, Actions, hook `use` | 19+ | `useMemo`/`useCallback` manuali dove servono |
| React — Server Components | 19+ con framework (Next.js…) | solo client component |
| Angular — naming file **senza** suffisso `.component`/`.service` | CLI 20+ (style guide 2025) | suffisso `.component.ts` / `.service.ts` |

Quando segnali un costrutto moderno mancante, **verifica prima** che la versione lo supporti. Se non lo supporta, o proponi l'equivalente idiomatico della versione in uso, oppure non sollevare il rilievo.

---

Leggi il file `$ARGUMENTS` per intero prima di procedere. Se non è specificato, usa il file aperto nell'IDE. Se il file supera ~1000 righe, leggi a blocchi con offset/limit e segnala che la revisione è parziale.

Identifica il tipo di file (componente, servizio/hook, store di stato, route/guard, modello/tipo, stile) e procedi con la revisione: prima i criteri comuni, poi la sezione specifica del framework rilevato.

---

## FASE 1 — Criteri comuni Frontend (Angular e React)

**1. Qualità e Clean Code**
- Componenti con responsabilità unica; file troppo grandi o componenti che fanno troppo (logica + presentazione + fetch dati insieme)
- Separazione tra componenti di **presentazione** (dumb) e componenti **contenitore** (smart)
- Duplicazione di codice (DRY); logica riutilizzabile estratta (service Angular / custom hook React)
- Naming descrittivo; magic number/stringhe hardcoded non costantizzate

**2. Tipizzazione (TypeScript)**
- Uso di `any` (esplicito o implicito) dove un tipo preciso è possibile
- `interface`/`type` per le strutture dati; props/input/output tipizzati
- Niente `as` (cast forzato) per aggirare errori del compilatore

**3. Sicurezza**
- XSS: inserimento di HTML non sanitizzato (vedi sezioni specifiche)
- Segreti/API key/token hardcoded o esposti nel bundle client (tutto ciò che è nel FE è pubblico)
- URL/`href` costruiti da input utente senza validazione (`javascript:`)

**4. Performance generale**
- Lavoro pesante eseguito a ogni render/change detection
- Liste lunghe senza virtualizzazione
- Asset/bundle non lazy-loaded quando possibile

**5. Commenti**
- **Diario di sviluppo nel sorgente** (livello **ATTENZIONE**, categoria `Commenti`): riferimenti a sottotask (`ST-n`), ticket, paragrafi di specifica, review ("fix review"), richieste in conversazione, cronistoria di bug, numeri di casi di test. Va nel commit o nella PR, non nel file. Indica dove spostarlo.
- **JSDoc/commenti che ripetono il codice** o duplicano quanto già scritto sopra — livello `INFO`.
- **Verbosità oltre il livello dichiarato** dal progetto (riga `- Commenti:` del `.claude/CLAUDE.md`; se manca vale `minimo`) — livello `INFO`. Soglie indicative: ~5% `minimo`, ~15% `standard`, ~30% `esteso` di righe di commento sul file.
- Restano legittimi a ogni livello: il perché di un workaround (incluso un bug noto di una libreria, con il link), i vincoli di accessibilità implementati, `TODO`/`FIXME` che dicono cosa manca.

**6. Accessibilità (base)**
- Elementi interattivi non semantici (`<div>` cliccabili senza ruolo/tasti)
- Immagini senza `alt`, label mancanti sui campi form

**7. Style guide e collocazione**

Le regole vincolanti (naming, collocazione dei tipi, struttura delle cartelle) **non sono elencate qui**: fonte unica il `CLAUDE.md` globale, § `## 2. Style Guide per Linguaggio` → *Convenzioni Frontend* e *Collocazione dei file e dei tipi*. Se non ti sono state iniettate nel prompt, leggile con **Read** da `~/.claude/CLAUDE.md` (`Read` espande `~`, anche su Windows; mai `%USERPROFILE%`). Convenzioni locali del progetto → priorità su tutto.

Riferimenti ufficiali: [Angular style guide](https://angular.dev/style-guide) · convenzioni React + ESLint (`eslint-plugin-react-hooks`, `jsx-a11y`) — React **non** prescrive una struttura di cartelle, il criterio è la **colocation**.

Come trattare le violazioni: livello tipico **ATTENZIONE**, categoria `Collocazione` o `Convenzioni Frontend`; scendi a **INFO** quando il file è solo disallineato da una struttura già consolidata nel progetto. Due trappole da evitare:

- **Naming Angular:** il suffisso `.component`/`.service` nel nome file dipende dalla versione (assente dalla style guide 2025, CLI ≥ 20; presente su ≤ 19). Guarda versione **e** file esistenti prima di segnalare: la convenzione dominante nel progetto vince.
- **Struttura per feature:** segnala le cartelle per tipo tecnico (`components/`, `services/`) solo su codice/feature **nuove**; su una codebase già organizzata così la coerenza vince e il rilievo è `INFO`.

---

## FASE 2 — Criteri specifici del framework

> Applica **solo** la sezione del framework rilevato in FASE 0, e **solo** i criteri supportati dalla versione (vedi REGOLA CRITICA).

### Se framework = ANGULAR (riferimento: 17-19)

**Architettura componenti**
- Componenti **standalone** per il codice nuovo; NgModule solo se il progetto è ancora module-based (coerenza col resto del codice)
- `ChangeDetectionStrategy.OnPush` sui componenti; nessun lavoro pesante nei getter usati dal template
- Separazione smart/dumb; `@Input()`/`@Output()` (o `input()`/`output()` se v17.1+) ben definiti

**Reattività e stato**
- **Signals** (`signal`/`computed`/`effect`) per lo stato locale quando supportati; evitare `BehaviorSubject` manuali dove i signals bastano
- Niente logica nel template oltre a semplici espressioni

**Dependency Injection e funzioni**
- `inject()` per le dipendenze quando la convenzione del progetto lo prevede
- Guard, interceptor e resolver scritti come **funzioni**, non classi (Angular ≥ 15/16)

**Template**
- Nuovo control flow `@if/@for/@switch` con `track` obbligatorio in `@for` (Angular ≥ 17); altrimenti `*ngIf/*ngFor` con `trackBy`
- `async` pipe per consumare observable nel template invece di `subscribe` manuale

**RxJS**
- Ogni subscription manuale ha un teardown: `async` pipe, oppure `takeUntilDestroyed()` (≥16) o `ngOnDestroy` + `Subject` + `takeUntil`
- Niente `subscribe` annidati (usa operatori di higher-order: `switchMap`, `concatMap`…)
- Niente `subscribe` dentro il template o dentro un altro `subscribe`

**Form e routing**
- Reactive forms tipizzati (Angular ≥ 14); evitare template-driven per form complessi
- Lazy loading delle route di feature

**Sicurezza Angular**
- Evitare `[innerHTML]` con dati non fidati; mai `bypassSecurityTrustHtml`/`...TrustUrl` su input utente
- Affidarsi alla sanitizzazione integrata di Angular; segnalare ogni bypass esplicito

### Se framework = REACT (riferimento: 18/19)

**Componenti e hooks**
- Solo **function component** + hooks; nessun class component nuovo
- **Rules of Hooks**: hook solo al top-level, mai dentro `if`/`for`/funzioni annidate; ordine costante
- Logica riutilizzabile estratta in **custom hook** (`useNomeXxx`)
- Componenti con responsabilità unica; evitare componenti enormi

**useEffect e side effect**
- Array delle dipendenze **esaustivo** (`react-hooks/exhaustive-deps`)
- Cleanup di timer, subscription, event listener nel return dell'effect (no memory leak)
- Evitare effect inutili: dati derivabili vanno calcolati **durante il render**, non sincronizzati con un effect

**Performance e memoization**
- React ≥ 19 con Compiler attivo → **non** aggiungere `useMemo`/`useCallback` ovunque: lascia ottimizzare il compiler; segnala solo i casi che il compiler non risolve (es. context provider troppo ampio)
- React < 19 (o senza compiler) → segnala prop **oggetto/array/funzione inline** passate a componenti memoizzati (nuova reference a ogni render = re-render inutile) e proponi `useMemo`/`useCallback` mirati
- Liste lunghe senza virtualizzazione

**Liste e key**
- `key` stabile e univoca; **mai l'indice** dell'array quando gli elementi possono riordinarsi/inserirsi/cancellarsi

**Stato e contesto**
- Stato collocato il più vicino possibile a dove serve (colocation); sollevare lo stato solo quando condiviso
- Context non troppo ampio (un context che cambia spesso fa ri-renderizzare tutti i consumer); splittare i context per frequenza di aggiornamento
- Componenti controllati per i form (`value` + `onChange`)

**Server vs Client (React 19 + framework)**
- Default a Server Component; `'use client'` solo dove serve interattività/stato/effetti
- Nessuna data fetching lato client per dati ottenibili sul server

**Sicurezza React**
- `dangerouslySetInnerHTML` solo con contenuto sanitizzato; mai con input utente grezzo
- `href`/`src` da input utente validati (no `javascript:`)
- Nessun segreto in variabili esposte al client (es. `NEXT_PUBLIC_*`, `import.meta.env` non prefissate correttamente)

---

## Formato di output per ogni problema

- **Livello:** [CRITICO | ATTENZIONE | INFO]
- **Categoria:** (es. Sicurezza, Performance, Architettura - Componente, RxJS, Hooks, ecc.)
- **Riga:** numero riga del file
- **Problema:** descrizione chiara in italiano
- **Soluzione:** come correggerlo, con un breve esempio di codice che mostra il pattern corretto **per la versione in uso**

> Se un rilievo dipende da un costrutto non supportato dalla versione del progetto, declassalo a `INFO / da verificare` e indica l'alternativa idiomatica della versione in uso.

---

## Riepilogo

- Framework e versione rilevati: [Angular/React vX]
- Numero totale: N critici, N attenzioni, N info
- Giudizio: **APPROVATO** / **APPROVATO CON RISERVE** / **DA RIVEDERE**
- Le 2-3 cose più urgenti da correggere prima del merge

---

## Salvataggio (solo uso standalone)

**Come capire se devi salvare:** guarda il prompt, non il chiamante. Se questi criteri ti sono stati **iniettati nel prompt da un orchestratore** (`code-reviewer` o `sviluppa`), **non salvare**: il salvataggio è dell'orchestratore. Salvi solo in **modalità standalone**, cioè quando li hai caricati tu dalla skill.

In modalità standalone salva la review su file (per `[YYYY-MM-DD]` usa la data odierna che trovi già nel tuo contesto di sessione, non serve ricavarla con Bash):

```
.claude/review/[YYYY-MM-DD]-[NomeFile]-review.md
```

Il file deve iniziare con uno stamp, seguito dal report:
```
Data: [YYYY-MM-DD]
Branch: [branch corrente]
Commit base: [sha corrente, da `git rev-parse HEAD`]
File analizzati: [NomeFile]

[report]
```

Crea la cartella `.claude/review/` se non esiste. Se `.claude/review/INDEX.md` non esiste, crealo con **Write** con l'intestazione `| Data | File | Branch | Esito | Stato |` più la prima riga. Se esiste già, leggilo con **Read** e usa **Edit** per aggiungere in coda alla tabella la riga (mai `Write` su un file esistente):
```markdown
| [YYYY-MM-DD] | [data]-[NomeFile]-review.md | standalone | N critici / N attenzioni | [APPROVATO / RISERVE / DA RIVEDERE] |
```

Se i criteri erano nel prompt (sei orchestrato), **non salvare** — il salvataggio lo gestisce l'orchestratore: `code-reviewer` nel report consolidato, `sviluppa` nel file di accumulo delle attenzioni del ciclo.

---

## Regole importanti
- Non essere generico; non ripetere il codice fornito
- Non fare assunzioni non supportate dal codice
- **Non suggerire mai un costrutto non disponibile nella versione del progetto**
- Se qualcosa non è verificabile, dichiaralo esplicitamente
- Dai priorità a problemi reali (sicurezza, bug, performance) rispetto a dettagli stilistici
