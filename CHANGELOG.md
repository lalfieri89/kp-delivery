# Changelog

Tutte le modifiche rilevanti a questo pacchetto sono documentate in questo file.
Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il versionamento [Semantic Versioning](https://semver.org/lang/it/).

## [1.5.0] - 2026-09-09

### Aggiunto
- **Hook `UserPromptSubmit` di presidio sul ciclo di sviluppo.** Quando il prompt contiene un verbo di sviluppo (`implementa`, `aggiungi`, `correggi`, `modifica`, `refactor`, …) e il comando `/sviluppa` non è stato digitato, inietta il promemoria della *Regola sviluppo*. Il problema che risolve: senza il comando esplicito la modifica veniva fatta a mano e `.claude/plan/` e `.claude/review/` restavano indietro, così la sessione successiva ripartiva da un contesto falso — il codice diceva una cosa, i documenti un'altra. Resta **silenzioso** se il prompt inizia con `/`, se contiene già `/sviluppa`, se non c'è un verbo di sviluppo o in caso di opt-out esplicito (`senza agenti`, `non usare la skill`, `fallo e basta`, `modifica veloce`, …). **Non bloccante**, per la stessa ragione dell'hook di commit: un `deny` colpirebbe anche il ciclo corretto, che scrive codice passando dagli stessi strumenti. Script inline `node -e` come gli altri due: nessun file da copiare, nessun path da risolvere sui tre OS.

### Modificato
- `CLAUDE.md`: **Regola sviluppo** in § *Delega agli agenti*, vincolante e nella stessa forma della Regola commit. Ogni richiesta che comporta scrittura o modifica di codice applicativo passa da `sviluppa` anche senza comando digitato, dichiarandolo in una riga. Con le eccezioni esplicitate: opt-out dell'utente (valido finché non cambia argomento), richieste che non toccano codice applicativo (domande, ricerche, git, `.claude/**`), e ciclo `sviluppa`/`coder`/`rilascio` già in corso, che non va annidato. Nel dubbio fra modifica banale e task di sviluppo vince la skill: un ciclo in più costa meno della documentazione disallineata. La riga corrispondente della tabella di delega era descrittiva (`"Implementa X / fai la feature Y"`) e non copriva le formulazioni fuori da quegli esempi.
- `install.sh` / `install.bat` / `README.md`: messaggi allineati al fatto che gli hook installati sono ora tre. Il README ne dichiarava ancora uno solo, da prima della 1.4.2.

## [1.4.3] - 2026-09-04

### Corretto
- **La FASE 1bis di `code-reviewer` veniva saltata in silenzio.** La fase esisteva dalla 1.4.0, ma nulla impediva di emettere il report senza averla eseguita: in un caso reale sono stati dichiarati 4 critici bloccanti che nessun verificatore aveva controllato, e la riga `Critici verificati:` semplicemente non compariva. Alla verifica successiva **nessuno dei quattro era un critico**: uno respinto come falso positivo (field injection segnalata come violazione, mentre è il pattern in 49 file su 50 del repo) e due declassati ad attenzione perché nascevano da codice preesistente e condiviso. Ora la fase è dichiarata non saltabile e il report non può essere prodotto senza i verdetti — con la nota che il salto avviene proprio quando i critici sono tanti e la verifica sembra costosa, cioè quando serve di più.
- **Verdict incoerente con i conteggi.** Il template non diceva come derivare il verdict per stack e l'agente lo sceglieva a mano: uno stack con 2 critici è stato marcato `APPROVATO CON RISERVE`. Ora il verdict si deriva meccanicamente (`critici > 0` → DA RIVEDERE; `critici = 0` e attenzioni > 0 → APPROVATO CON RISERVE; tutto a zero → APPROVATO), e la stessa regola vale per il totale.

### Aggiunto
- Agente `code-reviewer`: **tabella di riepilogo obbligatoria in chat** (critici / attenzioni / info per stack, con verdict) e riga finale che dichiara **se vale la pena aprire il report**. Il riepilogo esisteva solo dentro il file salvato: chi leggeva la chat doveva aprire il file per sapere se doveva aprirlo.
- Skill `rilascio`: davanti ai critici ora **offre di risolverli** (`Li sistemo io adesso?`) invece di limitarsi a `sistema questi punti e riavvia`. Se l'utente accetta, `coder` gira sui soli critici confermati con il vincolo di restare nel perimetro — un critico che nasce da codice preesistente si corregge nel percorso nuovo, non riscrivendo quel codice — e la review viene rilanciata prima di riaprire il gate.
- Skill `rilascio`: **controllo che i critici siano passati dal verifier** prima di presentarli come bloccanti. Se la riga `Critici verificati:` manca nel report, la verifica va rifatta invece di bloccare il rilascio su rilievi mai controllati.

### Modificato
- Skill `rilascio`: la regola "non modificare i file sorgente" contraddiceva la nuova FASE 2 Caso A. Ora distingue fra ciò che l'orchestratore non fa mai di sua iniziativa e l'unica modifica ammessa, delegata a `coder` su richiesta esplicita dell'utente.

## [1.4.2] - 2026-09-03

### Aggiunto
- **Hook `PreToolUse` di presidio sul flusso di commit.** Intercetta i comandi `git commit`, `git push` e `gh pr create` eseguiti direttamente in Bash e inietta un promemoria del flusso previsto (skill `commit-push-pr`: FASE 0 review pendenti, Pausa 1 conferma del messaggio, Pausa 2 conferma separata del push). **Non bloccante, per una ragione precisa:** la skill esegue git *attraverso* Bash e un hook non può sapere se la chiamata arriva da lei — un `deny` spegnerebbe anche il flusso corretto. Serve quindi come rete di sicurezza sul giudizio dell'agente, non come vincolo tecnico. Script inline `node -e` come per `SessionStart`: nessun file da copiare, nessun path da risolvere sui tre OS.
- `.claude/merge-settings.js`: **unisce tutti gli eventi hook**, non più solo `SessionStart`. Ogni evento presente nel sorgente viene creato se assente nel settings dell'utente e deduplicato per comando se già presente; gli hook dell'utente sullo stesso evento non vengono mai rimossi né riscritti, e un campo `hooks.<evento>` non valido fa saltare quel solo evento segnalandolo, senza annullare il resto del merge. Senza questa modifica il nuovo hook non sarebbe arrivato a chi ha già un `settings.json`.

### Modificato
- `CLAUDE.md`: **Regola commit** in § *Delega agli agenti*, vincolante. Ogni richiesta di commit/push/PR passa da `commit-push-pr` (o `/rilascio`); mai `git` a mano fuori dalla skill. Con l'eccezione esplicitata che mancava: il fatto che le istruzioni della skill siano **già nel contesto** da un'invocazione precedente non autorizza a rifarne i passi a memoria — le fasi non sono informazioni da ricordare ma passi da rieseguire, e ripercorrerle a mano salta i controlli per cui esistono. Un `ok` generico a un commit non vale come conferma del messaggio né come autorizzazione al push. La tabella di delega era descrittiva ("Situazione | Cosa usare") e non impediva la scorciatoia.
- `install.bat` / `install.sh`: messaggi allineati al fatto che gli hook installati sono ora due.

## [1.4.1] - 2026-09-03

### Corretto
- **`/init-project` non sovrascrive più il `.claude/CLAUDE.md` esistente.** Il PASSO 4 diceva "genera il file" seguito dal template completo, cioè un `Write` che riscriveva il file da zero con i soli campi raccolti dalle domande — anche scegliendo "aggiorna", che pre-compilava le risposte ma poi rigenerava comunque. Andava perso tutto ciò che sta fuori dal template, e in particolare la sezione `## Problemi noti test`: non è configurazione dell'utente, la popolano `java-test-reviewer` / `fe-test-reviewer` per non ripetere le stesse iterazioni nelle sessioni successive, e il template la reinseriva **vuota**. La perdita era silenziosa: nessuno se ne accorgeva fino al momento in cui quell'informazione serviva. Ora: `Write` solo se il file non esiste; su file esistente si interviene con `Edit` sui soli campi cambiati, dichiarando all'utente quali sono stati toccati. In PASSO 0.3 la skill fa l'**inventario del contenuto non riproducibile** (entry dei problemi noti, regole custom, sezioni non previste dal template) e lo mostra; l'opzione "sovrascrivi" è stata rimossa dalla domanda, e una riscrittura da zero richiesta esplicitamente va confermata voce per voce.
- `CLAUDE.md`: **Regola scrittura** in § *Conoscenza salvata tra sessioni* — nessun `Write` su un file di conoscenza già esistente, da parte di nessuna skill o agente; `Write` solo su file inesistente. La regola era già applicata correttamente da tutti i punti che scrivono `.claude/CLAUDE.md` e gli `INDEX.md`, ma esisteva solo come nota ripetuta a mano nelle singole skill: `init-project` era l'unico punto che la ignorava, ed era anche il solo che potesse azzerare l'intero file.

## [1.4.0] - 2026-09-03

### Aggiunto
- Skill/agente `task-planner`: campo **`File previsti`** su ogni sottotask (i path che l'ST prevede di toccare, `—` se non determinabili) e blocco di esito **`=== PIANO ===`** con le **ondate** di esecuzione ricavate dalle dipendenze. È il grafo che il piano già conteneva implicitamente, ora reso esplicito e leggibile dall'orchestratore.
- Skill `sviluppa`: **esecuzione a ondate**. I sottotask indipendenti girano in parallelo (max **2** `coder` concorrenti, lanciati nello stesso messaggio), quelli legati da una dipendenza restano in sequenza. Prima gli `ST-n` venivano eseguiti nell'ordine in cui comparivano nel piano, ignorando che molti erano indipendenti fra loro.
- Skill `sviluppa`: **controllo di sovrapposizione** prima di ogni ondata. Due ST che dichiarano lo stesso file in `File previsti` non sono indipendenti anche senza dipendenza dichiarata (dipendenza nascosta) e vengono degradati a sequenziale; un `File previsti: —` vale come "sovrapposto a tutti" e va da solo.
- Agente `code-reviewer`: **FASE 1bis — verifica dei rilievi CRITICI**. Prima di dichiarare bloccante un rilascio, ogni critico passa da tre verificatori indipendenti in parallelo (il riferimento esiste? il problema regge? riguarda il diff o è debito preesistente?), con contesto fresco e senza la conversazione del reviewer che l'ha prodotto. Maggioranza 2 su 3: confermato resta bloccante, altrimenti è **declassato ad attenzione** con il motivo. Nessun rilievo viene mai eliminato.
- **Telemetria dei loop**: `coder` e i due test-reviewer riportano `Iterazioni: N/5`, `sviluppa` chiude la FASE 2 con `Loop: N ST · M iterazioni coder totali · K risolti al primo giro · G giri critici` e la scrive nel file di accumulo. I tetti di iterazione erano numeri scelti a priori e mai misurati: ora si vede se sono tarati bene o se stanno mascherando criteri di successo formulati male.

- `CLAUDE.md`: sezione **Collocazione dei file e dei tipi** (Backend e Frontend). `service/` contiene solo classi di servizio: `data class`/`record`, `enum`, `sealed class`, `interface` di dato, DTO e modelli di risultato vanno in `dto/`, `model/`, `entity/`, `exception/` — **anche se usati da un solo Service**. Copre anche Java (una sola classe top-level per file) e Frontend (nessun tipo condiviso dentro un file di componente, struttura per feature, niente `utils.ts` contenitore). Era il buco per cui un modello dentro `service/` passava le review: la regola non esisteva, e "adeguati ai pattern esistenti" faceva replicare l'errore.
- `CLAUDE.md`: sezione **Convenzioni Java** (graffe sempre su `if`/`else`/`for`/`while` anche con corpo singolo — [Google Java Style §4.1.1](https://google.github.io/styleguide/javaguide.html), una classe top-level per file, package solo minuscoli, constructor injection, logger nei Service/Controller). Le graffe erano imposte su Kotlin e non su Java, dove sono la regola ufficiale.
- `CLAUDE.md`: sezione **Convenzioni Frontend**, con il naming dei file Angular **vincolato alla versione** — la style guide 2025 (CLI ≥ 20) genera file **senza** suffisso `.component`/`.service`, su ≤ 19 vale la convenzione storica. `fe-reviewer` imponeva i suffissi a prescindere.
- **Livello di commenti configurabile per progetto.** `/init-project` chiede quanto deve documentare chi scrive — `minimo` (default), `standard`, `esteso` — e scrive `- Commenti: [livello]` in `**Convenzioni:**` del `.claude/CLAUDE.md`. La riga viene scritta sempre, anche accettando il default, così il livello non dipende da un default che potrebbe cambiare. Sui progetti **già inizializzati** senza quel campo, `/init-project` lo segnala, fa la domanda e aggiunge la sola riga con `Edit` senza rigenerare il file (aggiunto `Edit` agli `allowed-tools`).
- `CLAUDE.md`: sezione **Commenti**, con la tabella dei tre livelli e tre **regole invarianti** valide a ogni livello, `esteso` compreso: (1) **niente diario di sviluppo nel sorgente** — nessun `ST-n`, ticket, "par. 5.5", "fix review", richiesta in conversazione, cronistoria di bug o numero di caso di test: quel contenuto va nel commit o nella PR, perché nel file nessuno ha davanti quel contesto e sopravvive alle modifiche continuando ad affermare cose non più vere; (2) **commenta il perché, non il cosa**; (3) **nessuna duplicazione** fra KDoc di classe e commenti inline. Un livello più alto non compra il diritto di violarle. Restano legittime a ogni livello le mappature verso naming esterni, il motivo di un parametro iniettabile, i riferimenti a norme o contratti, i `TODO`/`FIXME` che dicono cosa manca.
- Skill `java-spring-reviewer` e `fe-reviewer`: criterio **Commenti**. Violazione di un'invariante → **ATTENZIONE** (con l'indicazione di *dove* spostare il contenuto, non solo di cancellarlo); commenti che ripetono il codice, duplicazioni e verbosità oltre il livello dichiarato → `INFO`, con soglie indicative per file (~5% `minimo`, ~15% `standard`, ~30% `esteso` di righe di commento; header di classe oltre ~25 righe da guardare comunque). Sui commenti di codice preesistente non toccato dal diff i rilievi restano `INFO`: adeguare la documentazione altrui non è nel perimetro di chi modifica.
- Skill/agente `coder`: legge il livello di commenti dal `.claude/CLAUDE.md` di progetto e lo rispetta. Il divieto sul diario di sviluppo è esplicitato dove serve — il `coder` riceve nel prompt un piano con `ST-n`, ticket e note di review, e senza una regola contraria quel contesto finisce nei KDoc del codice che scrive.
- `CLAUDE.md`: regola **un componente Spring per file** — un file dichiara una sola classe `@Service`/`@Component`/`@Repository`/`@RestController`, col nome del file. Vale anche in Kotlin: la libertà di mettere più dichiarazioni nello stesso file resta per i **tipi di dato** correlati, non per i bean. Una classe di servizio accodata in fondo al file di un'altra (tipico `...Writer`/`...Guard` transazionale) è invisibile a chi cerca per nome e rende il file un contenitore; `java-spring-reviewer` e `code-reviewer` la segnalano ora esplicitamente (Grep su `^@(Service|Component|Repository|RestController)`).
- Agente `code-reviewer`: **controllo di collocazione a livello di orchestratore** (FASE 1). I sub-agenti ricevono un file alla volta e non possono giudicare l'albero dei package: il controllo sui path del diff è dell'orchestratore, che inietta anche le convenzioni nel prompt degli agenti (FASE 0.2b).

### Modificato
- **Convenzioni de-duplicate: fonte unica `CLAUDE.md`.** Le regole di stile e collocazione erano ricopiate in `CLAUDE.md`, `skills/coder`, `agents/coder`, `skills/java-spring-reviewer` e `agents/java-spring-reviewer`: cinque copie che andavano in drift a ogni modifica. Ora stanno **solo** in `CLAUDE.md` § `## 2. Style Guide per Linguaggio`; skill e agent le leggono con `Read` da `~/.claude/CLAUDE.md` (o le ricevono iniettate dall'orchestratore) e contengono soltanto il *come revisionarle*: livelli, categorie, note operative. Le convenzioni locali di un `.claude/CLAUDE.md` di progetto mantengono la priorità.
- Skill/agente `java-spring-reviewer`: la FASE 2b non elenca più le convenzioni Kotlin ma le carica dalla fonte unica, e aggiunge il trattamento dei rilievi — categorie `Collocazione` / `Convenzioni Java` / `Convenzioni Kotlin`, obbligo di verificare i package vicini con **Glob** prima di sollevare o escludere un rilievo di collocazione, e il divieto di segnalare come problema ciò che le convenzioni ammettono (su Kotlin più tipi correlati nello stesso file **sono** ammessi).
- `CLAUDE.md`, skill/agente `coder`, skill `java-spring-reviewer`: la regola sulle funzioni senza body `=` è resa esplicita per **tutti** i casi (top-level, membri, extension function, mapper `toDTO()`, override) e vietata anche **in sottrazione**: un diff che trasforma `{ return X }` in `= X` è una violazione, non una semplificazione.
- Skill `fe-reviewer`: il criterio 6 diventa *Style guide e collocazione*, con naming Angular version-gated (nuova riga nella tabella dei gate) e il chiarimento che React non prescrive una struttura di cartelle — il criterio ufficiale è la **colocation**.
- Skill/agente `coder`: il riepilogo finale diventa un **contratto a formato fisso**. Il blocco `=== CODER · ST-n ===` guadagna `Esito` (con il terzo valore `GATE UMANO RICHIESTO`), `Iterazioni: N/5` e un `File toccati` **parsabile come lista** — è il campo su cui `sviluppa` calcola le sovrapposizioni fra sottotask paralleli. Rimossa la riga `Prossimo:`: il passo successivo lo decide chi orchestra, non il `coder`.
- Skill `sviluppa`: la review mirata di FASE 2 gira **in parallelo su tutti i file dell'ondata** e l'esito è presentato **una volta sola per ondata**, in una tabella con la colonna `ST`, invece di una tabella per sottotask.
- Skill `sviluppa`: i gate umani sui sottotask si presidiano **prima di lanciare l'ondata** che li contiene (FASE 2 punto 2.0c) — i gate non si parallelizzano. I tre gate fissi del ciclo restano invariati.
- `README.md` e `CLAUDE.md`: allineate le descrizioni del ciclo, che parlavano ancora di implementazione e review "per sottotask".

### Note
- **Retrocompatibilità**: un piano privo del blocco `=== PIANO ===` (prodotto da una versione precedente) non è un errore — `sviluppa` tratta ogni `ST-n` come un'ondata a sé e procede in sequenza, esattamente come la 1.3.0. Il parallelismo si osserva quindi solo sui piani generati dopo l'aggiornamento.
- **Fallimento di un'ondata**: alla prima `NON SODDISFATTO` / `GATE UMANO RICHIESTO` l'ondata successiva non parte — la stessa garanzia della versione sequenziale. I sottotask fratelli già completati vengono comunque revisionati e mostrati, perché il loro codice è già sul disco. **Nessun rollback**: `sviluppa` non ha e non acquisisce logica git, che resta di `/rilascio`.

## [1.3.0] - 2026-08-06

### Aggiunto
- `CLAUDE.md`, skill/agente `coder` e skill/agente `java-spring-reviewer`: **Convenzioni Kotlin obbligatorie** (`companion object` in alto, funzioni con graffe e non `=`, graffe sugli `if` salvo inline, named parameter sempre, logger nel `companion object` dei Service + log all'ingresso dei metodi richiamati dal Controller).
- `code-reviewer` e `/sviluppa`: instradamento dei file **`.kt`** a `java-spring-reviewer` / `java-test-reviewer` (prima solo `.java`).

## [1.2.0] - 2026-07-31

### Aggiunto
- Skill `sviluppa`: l'esito della **review mirata di ogni sottotask** viene ora **mostrato allo sviluppatore** (tabella con conteggi per gravità + elenco dei rilievi CRITICO/ATTENZIONE) invece di essere scartato dall'orchestratore. Prima, chi non apriva la vista della skill in esecuzione non vedeva mai le attenzioni, che andavano perse.
- Skill `sviluppa`: i rilievi **non critici** vengono accumulati in `.claude/review/[data]-sviluppa-[slug].md` (stesso slug del piano) con stato `aperta`/`sistemata`/`accettata`, e **riproposti al GATE 2**, dove lo sviluppatore può chiederne la correzione prima del rilascio. Nessun gate aggiuntivo: su sole attenzioni la catena prosegue. Aggiunti `Write` ed `Edit` agli `allowed-tools`, necessari per il file di accumulo.

### Modificato
- Skill `sviluppa`: la FASE 2 chiede all'agente di review un **blocco di esito a formato fisso** (conteggi + una riga per rilievo), così l'orchestratore ha quanto serve per la tabella senza tirarsi in contesto il report integrale.
- Skill `sviluppa`: la FASE 3 chiede a `/rilascio` una **review fresca** («ignora il report esistente, rilancia l'analisi completa»). Prima, un secondo `/sviluppa` nella stessa giornata poteva rilasciare sulla base del report del mattino, perché `code-reviewer` per default riusa il report di oggi.
- Agenti e skill `java-spring-reviewer` / `fe-reviewer`: la regola di salvataggio del report non dipende più dal **chiamante** (`code-reviewer`) ma da **cosa c'è nel prompt** — se i criteri sono iniettati da un orchestratore non si salva, altrimenti sì. Prima, invocati da `sviluppa` ricadevano in un caso non coperto e il comportamento era non deterministico.

### Corretto
- Skill `sviluppa`: nell'introduzione l'agente `coder` era attribuito alla Fase 3 invece della Fase 2.

## [1.1.0] - 2026-07-08

### Aggiunto
- `VERSION` e `CHANGELOG.md` a livello di pacchetto; gli installer mostrano la versione nell'header.
- `.claude/merge-settings.js` (Node, cross-platform): se `~/.claude/settings.json` esiste già, l'hook SessionStart viene **unito** alla configurazione esistente invece di essere saltato. Idempotente, migra automaticamente il vecchio hook PowerShell, scrive UTF-8 senza BOM.
- `install.sh`: merge del `settings.json` esistente (parità con Windows; prima chiedeva il merge manuale).
- Check della presenza di `node` in entrambi gli installer.

### Modificato
- Hook SessionStart in `.claude/settings.json`: da `powershell -Command` a `node -e` — funziona identico su Windows, macOS e Linux (prima era rotto su Mac/Linux).
- `install.bat`: il merge del settings usa `merge-settings.js` (prima `merge-settings.ps1`, solo Windows).
- 6 skill (`task-planner`, `coder`, `java-spring-reviewer`, `java-test-reviewer`, `fe-reviewer`, `fe-test-reviewer`): frontmatter `allowed-tools` normalizzato con separatore a virgola.
- Agente `code-reviewer`: l'archiviazione dei vecchi report non blocca più la review in caso di errore.
- Skill `sviluppa`: FASE 1 chiarita (task-planner lanciato in standalone salva lui il piano e restituisce il path); FASE 2 passa a `coder` il path esplicito del piano e si ferma su esito NON SODDISFATTO; rimosso il riferimento a un parametro branch inesistente.
- Skill `rilascio`: la FASE 2 si ferma esplicitamente se il report di review non è stato prodotto.
- Skill `coder`: si ferma esplicitamente se il piano o l'ST-n richiesto non esistono.
- Skill `java-test-reviewer`: aggiunto `disable-model-invocation: true` (allineata alle skill reviewer sorelle).
- Skill `java-spring-reviewer`: aggiunta la sezione "Salvataggio (solo uso standalone)" (report + INDEX in `.claude/review/`), come `fe-reviewer` e l'agente omonimo.
- Skill `java-spring-reviewer` e `fe-reviewer`: aggiunto `Write` agli `allowed-tools` (necessario per il salvataggio standalone).
- Agente `java-test-reviewer`: aggiunto il caricamento dei criteri da `~/.claude/skills/java-test-reviewer/SKILL.md` in modalità standalone (unico agente che ne era privo).

### Corretto
- `.gitignore`: `merge-settings` ora è tracciato — prima il pacchetto clonato era privo dello script di merge invocato da `install.bat` (installer rotto su macchine con settings esistente).

### Rimosso
- `.claude/merge-settings.ps1` (sostituito da `merge-settings.js`).

## [1.0.0]

Versione iniziale distribuita: 11 skill, 7 agenti, installer Windows/macOS/Linux, hook SessionStart PowerShell.
