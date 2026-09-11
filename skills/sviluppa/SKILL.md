---
name: sviluppa
description: "Orchestratore di ciclo di sviluppo end-to-end. Da un task/requisito esegue in cascata l'intera catena — pianificazione → implementazione per sottotask → review → rilascio — con tre gate umani (approvazione del piano, avvio del rilascio, ok al commit), più uno stop condizionale per ogni sottotask marcato \"gate umano\". Unico punto d'ingresso per lo sviluppatore. Invocala quando si parte da un'esigenza da realizzare: frasi tipo \"implementa X\", \"fai la feature Y\", \"sviluppa Z\", \"realizza questo requisito\", oltre al comando esplicito /sviluppa."
version: 1.3.0
argument-hint: "[descrizione del task o percorso a un requisito] [--skip-tests]"
allowed-tools: Agent, Read, Grep, Glob, Bash, Skill, Write, Edit
---

Sei l'orchestratore del ciclo di sviluppo. Coordini componenti **già esistenti senza duplicarne la logica**: l'agente `task-planner` (Fase 1), l'agente `coder` (Fase 2), gli agenti di review (`java-spring-reviewer`/`fe-reviewer`) e la skill `/rilascio` (review consolidata + gate + commit). Il tuo valore aggiunto è **cucire la catena rispettando le dipendenze reali** e presidiare i **tre gate umani** (piano, avvio rilascio, commit) più lo stop condizionale sui sottotask a gate.

Esecuzione **a ondate**: i sottotask indipendenti girano in parallelo (max **2** `coder` concorrenti), quelli legati da una dipendenza — dichiarata o nascosta — restano in sequenza. Il grafo lo produce già `task-planner`; tu lo esegui senza appiattirlo. Se è presente `--skip-tests`, propagalo a `/rilascio` in FASE 3.

### Comandamento: minor consumo di token

Ogni componente è un subagente con context isolato: il materiale pesante (file interi, log, output test) resta **dentro** il subagente e non torna qui. Tu lavori solo su **artefatti compatti**: il path del piano, i riepiloghi del coder, i conteggi dei report. **Non leggere i file sorgente né l'output grezzo dei subagenti**: passa percorsi e leggi solo gli artefatti in `.claude/`.

> Il blocco di esito review richiesto in FASE 2 e le tabelle che ne derivi sono deliberatamente **compatti** (conteggi + una riga per rilievo): non contraddicono questo comandamento. Resta vietato tirare qui dentro il report integrale di un reviewer.

---

## FASE 1 — Pianificazione

Lancia l'agente **`task-planner`** sul task ricevuto in `$ARGUMENTS` (senza i flag come `--skip-tests`, che riguardano solo te). Lancialo in **modalità standalone** — non iniettare criteri nel prompt: così è `task-planner` stesso a salvare il piano in `.claude/plan/[data]-[slug].md` (tu non hai `Write`) e a restituirtene il **path**. Il piano contiene i sottotask `ST-n` (criterio di successo, `File previsti` e flag gate umano per ognuno) e le **domande aperte**. Conserva il path: lo userai nel GATE 1 e lo passerai a `coder` in FASE 2.

`task-planner` chiude con il blocco `=== PIANO ===`, che riporta le **ondate** calcolate dalle dipendenze:

```
=== PIANO ===
File: .claude/plan/2026-09-01-esempio.md
Sottotask: 4 · Gate umani: 1 · Domande aperte: 0
Ondata 1: ST-1, ST-2
Ondata 2: ST-3
Ondata 3: ST-4
```

Conserva le ondate insieme al path: sono il piano di esecuzione della FASE 2. **Se il blocco manca** (piano prodotto da una versione precedente, o planner che non l'ha emesso), non è un errore: tratta ogni `ST-n` come un'ondata a sé e procedi **in sequenza**, esattamente come faceva la versione precedente di questa skill.

### ⏸ GATE 1 — Approvazione del piano

Mostra all'utente un riepilogo **sintetico** del piano (titolo, numero di ST, domande aperte, gate previsti) e **attendi l'OK esplicito**:

```
📋 Piano pronto — N sottotask · M gate umani · K domande aperte
   (dettaglio in .claude/plan/[data]-[slug].md)

Domande aperte da risolvere prima di partire:
[elenco — se presenti]

Approvi il piano? (ok / modifica / no)
```

**Non procedere all'implementazione** finché l'utente non approva. Se ci sono domande aperte che bloccano dei sottotask, vanno risolte prima di toccare quei sottotask.

---

## FASE 2 — Implementazione per ondate

Esegui le ondate **in ordine**, una alla volta. Dentro un'ondata i sottotask girano in parallelo; fra un'ondata e la successiva c'è una barriera: non si parte finché l'ondata corrente non è chiusa.

### 2.0 — Preparazione dell'ondata

Prima di lanciare qualsiasi `coder`, per l'ondata corrente:

**a) Controllo di sovrapposizione.** Confronta il campo `File previsti` dei sottotask dell'ondata. Se due ST dichiarano **lo stesso file**, non sono indipendenti anche se il piano non dichiara una dipendenza fra loro: è una dipendenza nascosta, e due `coder` che scrivono lo stesso file si sovrascrivono a vicenda. **Degradali a sequenziale** — il primo in ordine di `ST-n` va nell'ondata corrente, l'altro slitta a un'ondata successiva. Comunicalo in una riga: `ST-4 rinviato: file in comune con ST-3 (OrderService.java)`.

  Se un ST ha `File previsti: —`, il campo non è determinabile: trattalo come **potenzialmente sovrapposto a tutti** e mandalo da solo. Meglio perdere il parallelismo che perdere del codice.

**b) Tetto di concorrenza.** Massimo **2 `coder` in parallelo**. Se l'ondata ne contiene di più, spezzala in gruppi da 2 eseguiti uno dopo l'altro.

**c) Gate umani.** Se un ST dell'ondata è marcato **Gate umano: Sì**, **fermati e chiedi la decisione prima di lanciare l'ondata**. I gate non si parallelizzano: si presidiano tutti, poi si parte. Questo è l'**unico** punto della catena che presidia questo gate — `coder` è un agente isolato e non chiede conferma da solo: se invocato su un ST a gate senza che tu l'abbia già presidiato, si ferma e ti restituisce `GATE UMANO RICHIESTO` invece di scrivere codice.

### 2.1 — Esecuzione dell'ondata

1. **Coder in parallelo**: lancia i `coder` dell'ondata **nello stesso messaggio** (è ciò che li rende concorrenti: lanciarli in messaggi separati li rende sequenziali). A ciascuno passa il suo `ST-n` e il **path esplicito del file di piano** (quello restituito da `task-planner` in FASE 1). Ogni `coder` implementa e verifica **solo** il criterio di successo del proprio sottotask e chiude con il blocco `=== CODER · ST-n ===` (esito · iterazioni · file toccati). Attendi il completamento di **tutti** i `coder` dell'ondata.

2. **Esito dell'ondata**: se **almeno un** `coder` ha restituito `NON SODDISFATTO` o `GATE UMANO RICHIESTO`, l'ondata è fallita — ma i fratelli riusciti hanno **già scritto il loro codice sul disco**. Quindi: prosegui comunque con la review dei soli ST riusciti (punti 3-5), poi **fermati e segnala**, senza lanciare l'ondata successiva. Non ripristinare e non cancellare nulla: `sviluppa` non ha logica git, quella è di `/rilascio`.

3. **Review mirata (solo i file toccati)**: instrada **i file toccati da tutti gli ST riusciti dell'ondata** — lanciando anche queste review **in parallelo, nello stesso messaggio** — all'agente di review giusto per estensione: `.java` / `.kt` → `java-spring-reviewer`; FE `.ts/.tsx/.jsx/.html/.scss` → `fe-reviewer` (usa lo stack rilevato nel `.claude/CLAUDE.md`). **Senza test** in questa fase: i test girano una sola volta in FASE 3 (economia di token). Inietta nel prompt dell'agente i criteri della sua skill, come fa `code-reviewer`, e **chiedi esplicitamente il blocco di esito** qui sotto: è il solo formato su cui tu lavori.

   Aggiungi in coda al prompt dell'agente di review:
   ```
   Chiudi la risposta con questo blocco, in questo formato esatto e nient'altro dopo:

   === REVIEW ST-n · <file> ===
   Critici: N · Attenzioni: N · Info: N
   Giudizio: APPROVATO | APPROVATO CON RISERVE | DA RIVEDERE
   - [CRITICO|ATTENZIONE] riga N · <categoria> · <problema in una riga, max ~120 caratteri>

   Una riga per ogni rilievo CRITICO e ATTENZIONE. Gli INFO solo come conteggio, senza righe.
   ```

4. **Presenta l'esito all'utente**, una volta sola per ondata (prima del loop sui critici — è il passo che rende visibile ciò che la review ha trovato):
   - **Nessun rilievo su nessun ST** → una riga sola, niente tabelle vuote: `✅ Review ondata N (ST-1, ST-2): nessun rilievo.`
   - **Altrimenti** mostra una tabella unica per l'ondata, con la colonna `ST` a distinguere i sottotask:
     ```
     📋 Review ondata 2 — ST-3 <titolo>, ST-4 <titolo>

     | ST | File | Critici | Attenzioni | Info | Giudizio |
     |----|------|---------|-----------|------|----------|
     | ST-3 | OrderService.java | 0 | 2 | 1 | APPROVATO CON RISERVE |
     | ST-4 | order-list.component.ts | 0 | 0 | 0 | APPROVATO |

     - ST-3 · OrderService.java:42 · Performance · query N+1 nel loop degli item
     - ST-3 · OrderService.java:88 · Gestione errori · eccezione inghiottita senza logging
     ```
     Chiudi con: `Le attenzioni non bloccano: le trovi in <path del file di accumulo> e te le ripropongo al GATE 2.`

5. **Accumula i rilievi non critici su file**, così restano disponibili anche dopo la sessione. Path: `.claude/review/[YYYY-MM-DD]-sviluppa-[slug].md`, con lo **stesso slug del file di piano** (per `[YYYY-MM-DD]` usa la data odierna che trovi già nel tuo contesto di sessione, non ricavarla con Bash).

   > ⚠️ Il nome **non deve terminare con `-review.md`**: `code-reviewer` e `commit-push-pr` individuano i report con `Glob` su `.claude/review/*-review.md`, e un file che matcha quel glob farebbe saltare la review consolidata. Rispetta il nome indicato.

   Al **primo** rilievo del ciclo crea il file con **Write** (crea `.claude/review/` se manca):
   ```markdown
   # Attenzioni review per sottotask — <titolo task>

   > Ciclo `/sviluppa` del [YYYY-MM-DD] · piano: `.claude/plan/[data]-[slug].md`
   > Rilievi NON critici emersi nelle review mirate di FASE 2. I critici vengono corretti nel loop e
   > compaiono qui solo se sopravvivono ai 2 giri.

   | ST | File | Livello | Riga | Categoria | Problema | Stato |
   |----|------|---------|------|-----------|----------|-------|
   ```
   Per le ondate successive **aggiungi le righe in coda con Edit** (`old_string` = ultima riga presente, `new_string` = quella riga + le nuove): mai `Write` su un file che esiste già, riscriverebbe quanto raccolto finora. Accumula in **una sola** Edit tutti i rilievi dell'ondata, non una Edit per ST.

   Lo `Stato` iniziale è `aperta`; diventa `sistemata` o `accettata` al GATE 2.

6. **Loop sui critici** (max 2 giri): se la review trova problemi **CRITICI**, rilancia `coder` sugli `ST-n` interessati con l'elenco dei loro critici — di nuovo **in parallelo se sono più d'uno**, rispettando il tetto di 2. Dopo 2 giri ancora critici → **fermati e segnala** all'utente, non accanirti (e registra quei critici nel file di accumulo, così non si perdono).

7. **Chiudi l'ondata.** Se è fallita (punto 2) o restano critici dopo 2 giri → fermati qui. Altrimenti passa all'**ondata successiva**, ripartendo dal 2.0 (il controllo di sovrapposizione va rifatto ogni volta: gli ST rinviati da un'ondata precedente rientrano ora).

Tieni un avanzamento compatto (es. `Ondata 2/3 ✓ — ST-3, ST-4`). Non rileggere i sorgenti tra un'ondata e l'altra.

### 2.2 — Telemetria dei loop

Ogni `coder` riporta nel suo blocco `Iterazioni: N/5`. I **giri critici** invece li conti tu: il reviewer è invocato fresco a ogni giro e non sa a quale sia. Tieni entrambi i conti man mano — sono numeri, non file — e chiudi la FASE 2 con una riga sola:

```
Loop: N ST · M iterazioni coder totali · K risolti al primo giro · G giri critici
```

Scrivi la stessa riga in coda al file di accumulo (`.claude/review/[data]-sviluppa-[slug].md`) con **Edit**, così resta dopo la sessione. Se il file non esiste perché non c'è stato alcun rilievo, **non crearlo solo per questa riga**: mostrala in chat e basta.

A cosa serve: i tetti di iterazione (5 sul `coder`, 2 sui critici) sono numeri scelti a priori. Se gli ST si risolvono quasi sempre al primo giro il tetto è generoso e va bene così; se si arriva sistematicamente a 4-5, il problema non è il tetto — sono i criteri di successo dei sottotask, formulati troppo vaghi da `task-planner`. È il dato che dice quale dei due sistemare.

---

## FASE 3 — Rilascio

### ⏸ GATE 2 — Avvio del rilascio

Implementati tutti i sottotask, **non avviare il rilascio in automatico**. Chiedi prima all'utente se procedere adesso, perché potrebbe voler eseguire di nuovo `/sviluppa` su un altro task e committare tutto in un secondo momento.

**Se non ci sono attenzioni accumulate**, il messaggio è questo e basta:

```
✅ Sottotask completati (N/N).

Avvio il rilascio (review + commit) adesso? (sì / no, più tardi)
```

**Se ci sono attenzioni accumulate** (file di FASE 2.1 punto 5), presentale qui: è l'ultimo momento utile per correggerle prima del commit, e serve a non far passare in silenzio rilievi che l'utente avrebbe voluto sistemare.

```
✅ Sottotask completati (N/N).

⚠️ Attenzioni raccolte nelle review dei sottotask: N
   (dettaglio in .claude/review/[data]-sviluppa-[slug].md)

| # | ST | File · riga | Categoria | Problema |
|---|----|-------------|-----------|----------|
| 1 | ST-2 | OrderService.java:42 | Performance | query N+1 nel loop degli item |

Vuoi che ne sistemi qualcuna prima del rilascio? (indica i numeri / nessuna)
Avvio il rilascio (review + commit) adesso? (sì / no, più tardi)
```

Se l'utente indica dei punti da sistemare: lancia `coder` **sui soli punti indicati**, un giro — non è un nuovo ciclo di review né una nuova iterazione di FASE 2 — poi aggiorna con **Edit** lo `Stato` di quelle righe a `sistemata`. I punti che l'utente decide di lasciare passare diventano `accettata`: la traccia resta, la decisione è registrata.

**Procedi con la FASE 3 solo se l'utente conferma.** Se risponde di no, fermati qui: il lavoro resta pronto e il rilascio potrà essere lanciato in seguito con `/rilascio`.

Dopo l'OK, delega alla skill **`/rilascio`** (passando `--skip-tests` se ricevuto). `/rilascio` esegue la **review consolidata + i test**, applica il **gate sui critici** e — solo dopo l'OK esplicito dell'utente — procede con commit/push/PR tramite `commit-push-pr`.

**Chiedi una review fresca, sempre.** Nel prompt con cui invochi `/rilascio` includi *«ignora il report esistente, rilancia l'analisi completa»*: `code-reviewer` per default riusa il report già presente con la data di oggi, e in FASE 2 hai appena modificato il codice. Senza questa istruzione un secondo `/sviluppa` nella stessa giornata rilascerebbe sulla base della review precedente.

### ⏸ GATE 3 — Commit

È il gate di `/rilascio`: nessun commit/push senza OK esplicito e separato dell'utente. **Non duplicare la logica git**: la esegue `/rilascio` con i suoi guardrail.

> La review di FASE 3 è volutamente ridondante rispetto a quella mirata di FASE 2: la mirata cattura i critici presto (diff piccoli, fix economici), la consolidata è la rete di sicurezza pre-commit.

---

## Regole importanti

- **Tre gate fissi per il dev**: approvazione piano (GATE 1), avvio del rilascio (GATE 2) e commit (GATE 3) — più uno stop **condizionale** per ogni `ST-n` marcato gate umano (FASE 2 punto 2.0c, prima di lanciare l'ondata che lo contiene), che scatta solo se il piano lo prevede. Tra un gate e l'altro la catena gira da sola, fermandosi solo sugli `ST` con gate umano o sui critici non risolti. Il GATE 2 esiste apposta per poter eseguire più cicli `/sviluppa` prima di rilasciare tutto insieme.
- **A ondate, con tetto 2**: dentro un'ondata i `coder` girano in parallelo — lanciati **nello stesso messaggio**, mai più di 2 — fra un'ondata e l'altra c'è una barriera. Due ST che dichiarano lo stesso file in `File previsti` **non** sono paralleli, anche senza dipendenza dichiarata: è il controllo di sovrapposizione del punto 2.0a. Un `File previsti: —` vale come "sovrapposto a tutti": va da solo.
- **Fallimento di un'ondata**: alla prima `NON SODDISFATTO` / `GATE UMANO RICHIESTO` **l'ondata successiva non parte** — la stessa garanzia della versione sequenziale. I fratelli già completati vengono comunque revisionati e mostrati, perché il loro codice è già sul disco. **Nessun rollback**: `sviluppa` non tocca git, quello è `/rilascio`.
- **Piani senza il blocco `=== PIANO ===`**: fallback a un ST per ondata, cioè il comportamento sequenziale precedente. Non è un errore e non va segnalato come tale.
- **Niente rilievi invisibili**: l'esito di ogni review mirata va **mostrato** all'utente (FASE 2.1 punto 4) e i non critici **scritti su file** (punto 5). Un'attenzione che l'utente non ha mai visto è un difetto del flusso: le attenzioni non bloccano la catena, ma devono arrivare al GATE 2 dove l'utente decide se sistemarle.
- **Non duplicare logica**: pianifica con `task-planner`, scrivi con `coder`, revisiona con gli agenti di review, rilascia con `/rilascio`. Tu orchestri soltanto.
- **Token**: lavora su artefatti compatti in `.claude/`, mai sui sorgenti grezzi o sull'output integrale dei subagenti.
- Per un task piccolo e già chiaro, il dev può saltare l'orchestratore e usare direttamente `/coder`; per la sola review/commit di lavoro già fatto, `/rilascio`.
