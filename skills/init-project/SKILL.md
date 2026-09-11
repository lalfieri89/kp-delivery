---
name: init-project
description: Inizializza la configurazione Claude Code per il progetto corrente (Backend Java e/o Frontend Angular/React). Rileva automaticamente lo stack, guida lo sviluppatore con domande mirate su stack, convenzioni, test e vincoli, poi genera il file .claude/CLAUDE.md locale con le personalizzazioni. Da eseguire una volta per ogni nuovo progetto.
version: 1.4.0
allowed-tools: Read, Write, Edit, Bash, Glob
---

Sei un assistente di setup. Il tuo obiettivo è raccogliere le informazioni sul progetto corrente e generare il file `.claude/CLAUDE.md` locale con le personalizzazioni specifiche.

---

## PASSO 0 — Verifica prerequisiti e rilevamento stack

1. Individua la root del progetto cercando `pom.xml`, `build.gradle` **o `package.json`** nella directory corrente e nelle parent directory.
   - Se non trovi nulla, avvisa: "Non riesco a trovare la root del progetto. Assicurati di eseguire questo comando dalla directory del progetto o da una sua sottocartella."
   - Se trovi più file (progetto multi-modulo o monorepo BE+FE), usa la root che li contiene; un progetto può avere **sia** backend **sia** frontend.

2. **Rileva automaticamente lo stack** e annuncialo all'utente prima delle domande (servirà a fare solo le domande pertinenti):
   - **Backend Java**: presenza di `pom.xml`/`build.gradle`. Prova a leggere la versione Java/Spring Boot da `pom.xml` (`<java.version>`, `spring-boot-starter-parent`) per pre-compilare.
   - **Frontend**: presenza di `package.json`. Leggi le dipendenze:
     - `@angular/core` → **Angular** (versione = valore della dipendenza)
     - `react`/`react-dom` → **React** (versione = valore della dipendenza)
   - Comunica: "Ho rilevato: [Backend Java X · Spring Boot Y] [Frontend Angular/React Z]. Confermi?" e salta i blocchi di domande non pertinenti.

3. Controlla se esiste già un file `.claude/CLAUDE.md` nella root del progetto.

   **Se non esiste** → procedi normalmente con le domande; lo genererai con `Write` in PASSO 4.

   **Se esiste**, leggilo per intero con **Read** e fai l'**inventario del contenuto non riproducibile** — tutto ciò che *non* potresti ricostruire dalle risposte alle domande di questa skill:
   - la sezione `## Problemi noti test` e le sue entry (le popolano `java-test-reviewer` / `fe-test-reviewer`: è memoria degli agenti, non configurazione dell'utente);
   - le righe di `**Regole custom:**` e ogni altra riga aggiunta a mano;
   - **qualsiasi sezione o riga che il template di PASSO 4 non prevede.**

   Mostra all'utente la sezione `## Contesto progetto` attuale e, se l'inventario non è vuoto, anche l'elenco di ciò che il file contiene in più. Poi chiedi: "Esiste già una configurazione per questo progetto. Vuoi aggiornarla o annullare?"
   - Se sceglie annulla → interrompi qui (salvo il punto 4 sotto, che riguarda i soli campi mancanti).
   - Se sceglie aggiorna → pre-compila le domande con i valori esistenti e chiedi solo conferma o modifica.

   **Non offrire "sovrascrivi".** Su un file esistente non si riscrive: si aggiornano i campi cambiati con `Edit` (PASSO 4, caso B). Se l'utente chiede esplicitamente di rifare il file da zero, mostragli l'inventario del contenuto non riproducibile e fatti confermare **voce per voce** cosa può essere buttato: `## Problemi noti test` non va buttata per default, perché il suo contenuto non è suo.

4. **Campi mancanti nei progetti già inizializzati.** Se il `.claude/CLAUDE.md` esiste ma la sezione `**Convenzioni:**` **non** contiene la riga `- Commenti:`, il progetto è stato inizializzato con una versione precedente del toolkit. Dillo all'utente, fai la domanda sul livello di commenti (PASSO 2, domanda 3) e aggiungi **solo quella riga** con **Edit**, senza rigenerare il resto del file — anche quando l'utente ha scelto "annulla" sulla riconfigurazione completa: è un campo mancante, non una riconfigurazione. Se l'utente non vuole rispondere, non scrivere nulla: l'assenza del campo vale già `minimo`.

---

## PASSO 1 — Stack Backend *(salta se non è stato rilevato un backend Java)*

Fai queste domande in un unico messaggio (pre-compila con i valori letti dal `pom.xml` in PASSO 0):

---
**Backend — rispondi sullo stack (lascia in bianco ciò che non sai o non è rilevante):**

1. **Versione Java** (es. 8, 17, 21) — *importante: determina quali costrutti i reviewer possono suggerire (es. i `record` esistono dalla 17)*
2. **Versione Spring Boot** (es. 2.7, 3.3, 3.4)
3. **Database** (es. PostgreSQL, MySQL, Oracle, H2)
4. **Altri componenti rilevanti** (es. Redis, Kafka, Elasticsearch — o lascia vuoto)
---

Attendi la risposta prima di procedere.

---

## PASSO 1B — Stack Frontend *(salta se non è stato rilevato un frontend)*

Fai queste domande in un unico messaggio (pre-compila con i valori letti dal `package.json`):

---
**Frontend — rispondi sullo stack:**

1. **Framework e versione** (es. Angular 14, Angular 18, React 17, React 19) — *importante: determina quali costrutti i reviewer possono suggerire (es. il control flow `@if/@for` esiste da Angular 17, il React Compiler da React 19)*
2. **Runner di test** (es. Karma+Jasmine, Jest, Vitest — o lascia vuoto se non sai)
3. **Gestione dello stato** (es. NgRx / Signals per Angular; Redux / Zustand / Context per React — o lascia vuoto)
4. **Linter/formatter** (es. ESLint, Prettier — o lascia vuoto)
---

Attendi la risposta prima di procedere.

---

## PASSO 2 — Convenzioni

Fai queste domande in un unico messaggio:

---
**Convenzioni del progetto:**

1. **Branch principale** — qual è il branch di destinazione per le PR? (es. main, master, develop)
2. **Lingua dei commit** — italiano o inglese?
3. **Livello di commenti nel codice** — quanto deve documentare chi scrive? *(default: `minimo`)*
   - **`minimo`** — nessun KDoc/Javadoc/JSDoc per default; si commenta solo dove il perché non è deducibile dal codice (workaround, vincolo esterno, scelta contro-intuitiva)
   - **`standard`** — KDoc di 1-3 righe su classi e metodi pubblici, più i commenti sul perché
   - **`esteso`** — KDoc su tutti i membri (private incluse), `@param`/`@return` sistematici, header di classe con le regole di business
---

> Sul livello di commenti, se l'utente chiede a cosa serve: vale a ogni livello il divieto di scrivere nel sorgente il **diario di sviluppo** (numeri di sottotask, ticket, "fix review", cronistoria dei bug) — il livello governa solo *quanta* documentazione produrre, non permette quel contenuto.

Attendi la risposta prima di procedere.

---

## PASSO 3 — Test e vincoli

Fai queste domande in un unico messaggio:

---
**Test e vincoli:**

1. **Framework di test aggiuntivi** *(solo se backend Java)* — usi Testcontainers, WireMock, o altri? (lascia vuoto se usi solo Mockito/MockMvc)
2. **Cartelle da non toccare** — ci sono moduli o cartelle che gli agenti non devono analizzare o modificare? (es. `src/legacy/`, `node_modules/`, `modulo-deprecato/`)
3. **Regole custom** — ci sono vincoli specifici del team che vuoi che gli agenti rispettino? (es. "no Lombok", "usa sempre ResponseEntity" lato BE; "no `any`", "solo componenti standalone", "niente `dangerouslySetInnerHTML`" lato FE)
---

Attendi la risposta prima di procedere.

---

## PASSO 4 — Scrittura del file

Crea la cartella `.claude/` se non esiste:
```bash
mkdir -p <root-progetto>/.claude
```

Come scrivere dipende da cosa hai trovato in PASSO 0.3 — la distinzione **non è opzionale** (vedi `CLAUDE.md` § *Regola scrittura*):

**Caso A — il file non esisteva:** genera `.claude/CLAUDE.md` con **Write**, usando il template qui sotto.

**Caso B — il file esisteva:** **mai `Write`.** Applica con **Edit** solo i campi le cui risposte sono cambiate, uno per uno, lasciando intatto tutto il resto — in particolare la sezione `## Problemi noti test` con le sue entry e ogni sezione o riga non prevista dal template. Se manca del tutto una sezione prevista (es. `**Frontend:**` su un progetto diventato misto), aggiungila con `Edit` nella posizione corrispondente del template. Al termine dichiara all'utente **quali campi hai toccato** e conferma che il resto del file è rimasto invariato.

> Il template descrive la **struttura di riferimento**, non un file da rigenerare a ogni esecuzione: nel caso B serve a sapere dove va un campo, non a sostituire ciò che c'è.

Il file deve avere questa struttura — compila solo i campi per cui hai ricevuto una risposta, ometti le righe vuote:

```markdown
## Contesto progetto

**Stack:**           <!-- solo se backend Java -->
- Java [versione]
- Spring Boot [versione]
- Database: [db]
[- Altri: componenti aggiuntivi se presenti]

**Frontend:**        <!-- solo se frontend Angular/React -->
- Framework: [Angular | React] [versione]
- Runner di test: [Karma+Jasmine | Jest | Vitest]
- Gestione stato: [NgRx/Signals | Redux/Zustand/Context]
- Cartelle FE: [percorso, es. src/app/ o src/]

**Convenzioni:**
[- Naming DB: schema dichiarato, es. snake_case con prefisso tbl_ (solo BE)]
[- Package: organizzati per layer | feature (solo BE)]
- Branch principale: [branch]
- Lingua commit: [italiano | inglese]
- Commenti: [minimo | standard | esteso]

**Test:**
[- Framework aggiuntivi BE: elenco se presenti]
[- Stack per layer BE: Mockito (Service), MockMvc (Controller), DataJpaTest (Repository), Testcontainers se dichiarato]
[- Stack FE: runner dichiarato + React/Angular Testing Library]

**Non toccare:**
[- elenco cartelle/moduli dichiarati come esclusi]

**Regole custom:**
[- elenco regole dichiarate dal developer]

## Problemi noti test
<!-- Popolato automaticamente dagli agenti di test (java-test-reviewer / fe-test-reviewer) quando il fix loop fallisce dopo 5 iterazioni.
     Formato: [YYYY-MM-DD] `nomeTest` — errore: ... — causa: ... — fix: ... -->
```

La riga `- Commenti:` va scritta **sempre**, anche quando l'utente ha accettato il default (in quel caso vale `minimo`): il campo esplicito evita che il livello dipenda da un default che potrebbe cambiare.

Ometti intere sezioni (`**Stack:**`, `**Frontend:**`, `**Test:**`, `**Non toccare:**`, `**Regole custom:**`) se non hai ricevuto informazioni per quella sezione — in particolare includi `**Stack:**` solo per progetti backend e `**Frontend:**` solo per progetti frontend (un progetto misto le ha entrambe). **Non omettere mai la sezione `## Problemi noti test`** — è necessaria per la memoria degli agenti tra sessioni. E se esisteva già con delle entry, **le entry restano**: la sezione non va reinserita vuota (è il modo più facile di azzerare la memoria degli agenti senza che nessuno lo noti).

---

## PASSO 4B — SessionStart hook

Assicurati che esista il file `.claude/settings.json` con il SessionStart hook per l'iniezione automatica del contesto. Se il file non esiste o non contiene il hook, crealo (o aggiornalo preservando le impostazioni esistenti) con:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node -e \"const fs=require('fs');const p=['.claude/CLAUDE.md','CLAUDE.md'].find(f=>fs.existsSync(f));process.stdout.write(p?fs.readFileSync(p,'utf8'):'Nessun CLAUDE.md trovato. Usa /init-project per inizializzare il contesto del progetto.')\""
          }
        ]
      }
    ]
  }
}
```

Il file `.claude/settings.json` viene già creato in PASSO 4 (la cartella `.claude/` esiste). Questo hook garantisce che il contesto di progetto venga iniettato automaticamente ad ogni nuova sessione, senza che ogni agente debba rileggerlo.

**Nota:** usa sempre `node -e` (funziona identico su Windows, macOS e Linux), mai `powershell -Command` — quella forma è rotta su Mac/Linux ed è la versione legacy che le installazioni precedenti devono migrare.

## PASSO 4C — Guida .gitignore

Controlla se esiste un `.gitignore` nella root del progetto. Chiedi al developer:

> La cartella `.claude/review/` contiene report di code review generati da Claude. Vuoi includerla nel repository (utile per condividerla con il team) o escluderla dal git?

- Se escludere → aggiungi al `.gitignore` (crealo se non esiste):
  ```
  # Output generati da agenti Claude
  .claude/review/
  ```
- Se includere → non fare nulla (la cartella sarà condivisa col team)

**Nota:** `.claude/CLAUDE.md` del progetto (che include `## Problemi noti test`) è invece raccomandato **includere** nel git — è conoscenza condivisa del team, non output personale.

## PASSO 5 — Conferma e riepilogo

Dopo aver scritto il file, mostra all'utente:

```
Configurazione salvata in <path-assoluto>/.claude/CLAUDE.md

Backend:      [Java X · Spring Boot X · DB  oppure "—"]
Frontend:     [Angular/React X · runner test  oppure "—"]
Branch:       [branch]
Lingua:       [lingua commit]
Esclusi:      [cartelle o "nessuno"]
Regole:       [N regole custom o "nessuna"]

Gli agenti leggeranno questa configurazione automaticamente ad ogni sessione.
Per aggiornarla in futuro, esegui di nuovo /init-project.
```

---

## Regole importanti

- Non chiedere tutte le domande in una volta sola — rispetta i gruppi (Backend, Frontend, Convenzioni, Test/vincoli) e salta quelli non pertinenti allo stack rilevato
- Non inventare valori non forniti dall'utente — ometti il campo
- Non toccare il CLAUDE.md globale in `~/.claude/CLAUDE.md`
- Il file generato va nella root del progetto, non nella home
- Se l'utente non fornisce una risposta per un campo, non inserire placeholder come "N/A" o "da definire" — ometti la riga
