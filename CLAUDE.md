# CLAUDE.md

Linee guida comportamentali per ridurre gli errori comuni nello sviluppo con LLM. Da integrare con le istruzioni specifiche del progetto.

**Principi:** KISS (soluzione più semplice che funziona) · YAGNI (non scrivere codice per esigenze future ipotetiche) · DRY (ogni logica ha un'unica rappresentazione) · SOLID (S: una responsabilità per classe · O: aperta all'estensione, chiusa alla modifica · L: sottoclasse sostituisce padre senza rompere · I: interfacce piccole e specifiche · D: dipendi da astrazioni, non da implementazioni)

**Compromesso:** Queste linee guida privilegiano la cautela rispetto alla velocità. Per i task banali, usa il buon senso.

## 1. Pensa Prima di Scrivere Codice

**Non dare nulla per scontato. Non nascondere la confusione. Porta in superficie i compromessi.**

Prima di implementare:
- Dichiara esplicitamente le tue assunzioni.
- Se esistono più interpretazioni: se una è chiaramente più semplice → sceglila e dichiarala ("assumo X"); se sono equivalenti e l'azione è irreversibile → chiedi; per task reversibili non chiedere — esegui e segnala.
- Se esiste un approccio più semplice, dillo. Metti in discussione quando è opportuno.
- Se qualcosa non è chiaro, fermati. Nomina cosa ti confonde in una riga.

## 2. Style Guide per Linguaggio

**Segui sempre lo style guide ufficiale del linguaggio in uso.**

- Kotlin → [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Java → [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- Per altri linguaggi → usa lo style guide ufficiale del linguaggio o del framework

Se il progetto ha una convention locale che devia dallo style guide, quella locale ha priorità. Segnala la deviazione se non è documentata.

**Prima di scrivere o modificare codice, ispeziona i pattern già usati nel progetto e adeguati a quelli.** Cerca esempi esistenti dello stesso costrutto (dichiarazione di logger, gestione eccezioni, struttura DTO/Service, naming, formattazione) e replica la forma prevalente nel codice circostante. La coerenza con il codice esistente ha priorità sulla tua preferenza personale, anche quando entrambe sono valide. Se trovi più pattern in conflitto, segui quello dominante nei file vicini e segnala l'incoerenza.

### Collocazione dei file e dei tipi (obbligatoria — Backend e Frontend)

Un tipo nel package sbagliato è un errore di pari gravità di un metodo scritto male: va segnalato in review e corretto. Vale su codice nuovo **e** su codice esistente che si sta modificando.

**Backend (Java e Kotlin)**

- **`service/` contiene solo classi di servizio** — cioè classi annotate `@Service` (più gli eventuali collaboratori `@Component` di quel layer). Nessuna `data class`/`record`, `enum`, `sealed class`, `interface` di dato, DTO o modello di risultato può stare lì, **nemmeno se è usato da un solo Service**: "lo usa solo lui" non è una motivazione valida.
- **Un componente Spring per file** — un file di servizio dichiara **una sola** classe annotata `@Service`/`@Component`/`@Repository`/`@RestController`, e il nome del file è quello di quella classe. Vale anche in Kotlin, dove il linguaggio permetterebbe di accodarne altre: una seconda classe di servizio (un `...Writer`, un `...Guard`, un `...Resolver` transazionale) nascosta in fondo al file di un'altra è invisibile a chi cerca per nome, e trasforma un file che dovrebbe avere una responsabilità in un contenitore. Se serve, **file proprio**.
- Dove va ciascun tipo: DTO di request/response esposti dai Controller → `dto/` · modelli di dominio e risultati di calcolo interni (es. `PricingResult`, `PrezzoBreakdownAnno`) → `model/` · entity JPA → `entity/` · eccezioni → `exception/`. Se il progetto usa nomi diversi (`domain/`, `payload/`, `record/`, …) si seguono quelli esistenti — ma **mai** `service/`.
- La stessa regola vale per gli altri layer: niente tipi di dato dentro `controller/`, `repository/`, `config*/`.
- **Java: una sola classe top-level per file** ([Google Java Style §3.4.1](https://google.github.io/styleguide/javaguide.html#s3.4-class-declaration)), e il nome del file coincide con quello della classe.
- **Kotlin: più dichiarazioni nello stesso file sono ammesse, ma solo per i tipi di dato** — le [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html#source-file-organization) lo incoraggiano se i tipi sono semanticamente correlati e il file resta di poche centinaia di righe, e su questo **non** deviamo: `data class`, `enum`, `sealed class` e interfacce di dato correlate possono convivere. Restano fuori le **classi di servizio**, che seguono la regola del punto precedente: una per file. Il file deve comunque stare nel package giusto e il suo nome deve descrivere ciò che contiene: se `PricingResult.kt` finisce per ospitare anche tipi di plafond, va splittato.

**Frontend (Angular e React)**

- Nessun `interface`/`type`/`enum` **condiviso** dichiarato dentro il file di un componente: se lo usa più di un file, ha un file proprio (Angular: file di modello nella cartella della feature; React: `types.ts` accanto alla feature). Un tipo usato solo da quel componente può restare nel suo file.
- **Struttura per feature, non per tipo tecnico** — la [Angular style guide](https://angular.dev/style-guide) prescrive di organizzare in sottocartelle per feature e di **evitare** cartelle create per tipo di file (`components/`, `services/`, `directives/`); React non prescrive nulla e raccomanda la **colocation** (tenere vicini i file che cambiano insieme). In entrambi i casi: se il progetto ha già una struttura, quella vince (vedi sopra) — la regola si applica al codice nuovo e alle feature nuove.
- **Un concetto per file**; niente `utils.ts`/`helpers.ts` contenitore.

### Commenti (obbligatoria — ogni linguaggio)

**Livello del progetto.** Il `.claude/CLAUDE.md` del progetto dichiara `- Commenti: [minimo | standard | esteso]` in `**Convenzioni:**`. Se il campo manca, il default è **`minimo`**.

| Livello | Cosa si scrive |
|---------|----------------|
| `minimo` *(default)* | Nessun KDoc/Javadoc/JSDoc per default. Si commenta **solo** dove il perché non è deducibile dal codice e la sua assenza farebbe sbagliare: workaround, vincolo esterno, scelta contro-intuitiva, unità di misura non ovvia. |
| `standard` | KDoc di **1-3 righe** su classi e metodi **pubblici**, più i commenti sul perché. Nessun `@param`/`@return` che ripeta la firma. |
| `esteso` | KDoc su tutti i membri, `private` incluse; `@param`/`@return` sistematici; header di classe che documenta le regole di business implementate. |

**Regole invarianti — valgono a *tutti* i livelli, `esteso` compreso.** Sono le violazioni più gravi e non si comprano con un livello più alto:

1. **Niente diario di sviluppo nel codice.** Nessun riferimento a sottotask (`ST-n`), ticket, paragrafi di specifica ("par. 5.5"), review ("fix review", "rilievo del reviewer"), richieste in conversazione ("vincolo esplicito dell'utente"), cronistoria di un bug o numeri di un caso di test. Quel contenuto va nel **messaggio di commit**, nella **descrizione della PR**, o in un **test con un nome che lo dichiara** — non nel sorgente, dove nessuno del team ha davanti quel contesto e dove sopravvive alle modifiche del codice continuando ad affermare cose non più vere.
2. **Commenta il perché, non il cosa.** Un commento che riformula la riga sotto è rumore. Se serve un commento per capire *cosa* fa il codice, il problema è il nome o la struttura: si sistema quello, non si aggiunge il commento.
3. **Nessuna duplicazione.** Se l'informazione è già nel KDoc di classe, il commento inline non la ripete. Un `// vedi KDoc di classe` è il sintomo che c'è una copia di troppo.

Restano sempre legittimi, a ogni livello: la mappatura verso un naming esterno diverso, il motivo di un parametro iniettabile, il riferimento a una norma o a un contratto di integrazione, un `TODO`/`FIXME` con l'indicazione di cosa manca.

**Come si modifica il codice esistente:** non si riscrive la documentazione altrui per adeguarla al livello (§ 4 Modifiche Chirurgiche). Ma se stai già modificando quella funzione e il commento è **falso** o è un diario di sviluppo, si corregge o si rimuove insieme alla modifica.

### Convenzioni Java (obbligatorie)

Riferimento: [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html). Le regole sotto sono quelle che vanno verificate sempre, perché sono le più disattese:

1. **Graffe sempre** su `if` / `else` / `for` / `while` / `do`, anche con corpo di una sola istruzione o vuoto ([§4.1.1](https://google.github.io/styleguide/javaguide.html#s4.1.1-braces-always-used)). Nessuna eccezione: è la stessa regola imposta su Kotlin.
2. **Una classe top-level per file**, nome file = nome classe (vedi § Collocazione).
3. **Nomi di package solo minuscoli**, senza underscore e senza camelCase (`it.azienda.internalmarket`, non `it.azienda.internalMarket`).
4. **Constructor injection**, non `@Autowired` su campo; dipendenze `private final`.
5. **Logger nei Service e nei Controller** — coerente col pattern già in uso nel progetto (`@Slf4j`, `LoggerFactory`, …): nei metodi invocati dal Controller loggare almeno l'ingresso con i parametri rilevanti.

### Convenzioni Frontend (obbligatorie)

Riferimenti: [Angular style guide](https://angular.dev/style-guide) · convenzioni React ufficiali + ESLint (`eslint-plugin-react-hooks`, `jsx-a11y`).

1. **Naming file Angular vincolato alla versione** — la style guide 2025 (CLI **Angular ≥ 20**) genera file **senza suffisso di tipo**: `user-profile.ts` / `user-profile.html`, `user-profile-service.ts`. Su progetti **Angular ≤ 19** (o che hanno esplicitamente scelto l'opt-out) resta la convenzione storica `user-profile.component.ts` / `user-profile.service.ts`. **Verifica sempre come sono chiamati i file esistenti e replica quello**: non imporre la convenzione nuova su una codebase vecchia, né viceversa.
2. **Sempre kebab-case** con parole separate da `-`, test in `*.spec.ts` accanto al codice testato.
3. **Niente `any`**, niente cast `as` per zittire il compilatore.
4. Collocazione di tipi e struttura cartelle: vedi § Collocazione.

### Convenzioni Kotlin (obbligatorie — prevalgono sullo style guide ufficiale)

Queste regole valgono **sempre** su codice Kotlin nuovo o modificato, anche quando le [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html) suggeriscono diversamente.

1. **`companion object` in alto** — subito dopo la dichiarazione di classe / proprietà di classe, come i membri `static` in Java. Non metterlo in fondo al file.
2. **Niente body con `=` per le funzioni — mai, nessuna eccezione** — ogni funzione ha il blocco con graffe `{ ... }` e un `return` esplicito, anche se il corpo è una sola espressione. Vale per funzioni top-level, membri, private, extension function, mapper/`toDTO()`, override, lambda-like: **tutte**.
   - No: `fun foo(): Int = 1`
   - Sì: `fun foo(): Int { return 1 }`
   - No:
     ```kotlin
     private fun Plafond.toDTO(): PlafondRowDTO = PlafondRowDTO(
         id = id,
     )
     ```
   - Sì:
     ```kotlin
     private fun Plafond.toDTO(): PlafondRowDTO {
         return PlafondRowDTO(
             id = id,
         )
     }
     ```
   - **È vietato togliere graffe e `return` da codice esistente** che già li ha: non è una semplificazione, è una violazione (vedi anche § 4 Modifiche Chirurgiche). Se un diff trasforma `{ return X }` in `= X`, il diff è sbagliato e va rifatto.
3. **Graffe sempre sugli `if`** — ogni ramo `if` / `else if` / `else` ha le graffe, anche se il corpo è una sola riga. Eccezione: solo l'espressione `if`/`else` **inline** usata come valore (es. `val x = if (cond) a else b`).
4. **Named parameter sempre** — in ogni chiamata a funzione/costruttore con argomenti, passare i parametri per nome (`foo(id = id, name = name)`), non posizionalmente.
5. **Logger nei Service** — ogni Service ha un `logger` nel `companion object`. Nei metodi invocati dal Controller, loggare **almeno** l'ingresso (richiamo del metodo), con i parametri rilevanti dove utile.

Esempio di forma attesa per un Service:

```kotlin
@Service
class EsempioService(
    private val repository: EsempioRepository,
) {
    companion object {
        private val logger = LoggerFactory.getLogger(EsempioService::class.java)
    }

    fun trovaPerId(id: Long): EsempioDto {
        logger.info("trovaPerId chiamato con id={}", id)
        // ...
        return EsempioDto(
            id = entity.id,
            nome = entity.nome,
        )
    }
}
```

## 3. Semplicità Prima di Tutto

**Il minimo codice necessario per risolvere il problema. Niente di speculativo.**

- Nessuna funzionalità oltre a quelle richieste.
- Nessuna astrazione per codice usato una sola volta.
- Nessuna "flessibilità" o "configurabilità" non richiesta.
- Nessuna gestione degli errori per scenari impossibili.
- Se scrivi 200 righe e ne basterebbero 50, riscrivilo.

Chiediti: "Un senior engineer direbbe che è troppo complicato?" Se sì, semplifica.

## 4. Modifiche Chirurgiche

**Tocca solo quello che devi. Pulisci solo il tuo disordine.**

Quando modifichi codice esistente:
- Non "migliorare" codice, commenti o formattazione adiacenti.
- Non fare refactoring di cose che non sono rotte.
- Rispetta lo stile esistente, anche se tu lo faresti diversamente.
- Se noti codice morto non correlato, segnalalo — non cancellarlo.

Quando le tue modifiche creano orfani:
- Rimuovi import/variabili/funzioni resi inutilizzati DALLE TUE modifiche.
- Non rimuovere codice morto preesistente a meno che non sia richiesto.

Il test: ogni riga modificata deve essere direttamente riconducibile alla richiesta dell'utente.

## 5. Esecuzione Orientata agli Obiettivi

**Definisci i criteri di successo. Itera finché non sono verificati.**

Trasforma i task in obiettivi verificabili:
- "Aggiungi validazione" → "Scrivi test per input non validi, poi falli passare"
- "Correggi il bug" → "Scrivi un test che lo riproduca, poi fallo passare"
- "Refactoring di X" → "Assicurati che i test passino prima e dopo"

Per task in più passi, indica un piano breve:
```
1. [Passo] → verifica: [controllo]
2. [Passo] → verifica: [controllo]
3. [Passo] → verifica: [controllo]
```

Criteri di successo forti ti permettono di iterare in autonomia. Criteri deboli ("fallo funzionare") richiedono continui chiarimenti.

## 6. Comunicazione

**Risposta proporzionale al task. Niente rumore.**

- **Lingua: sempre italiano** — anche se l'utente mescola termini inglesi, anche se il contesto (codice/output) è in inglese. Non derivare mai verso l'inglese.
- Domanda semplice → risposta breve, niente sezioni e intestazioni
- Non riassumere ciò che hai appena fatto — il diff parla
- Non elencare i passi che stai per fare: falli, poi riferisci solo se rilevante
- Se sei bloccato, nomina il blocco in una riga — non tre paragrafi

## 7. Commit

**Il messaggio di commit contiene solo quello che serve al team.**

- **Nessuna traccia dell'assistente**, da nessuna parte: né il trailer `Co-Authored-By` nei commit,
  né la firma `Generated with Claude Code` nel corpo delle Pull Request, né riferimenti equivalenti
  in branch, tag, descrizioni di PR/MR o commenti. Il lavoro non deve dichiarare con quale strumento
  è stato prodotto. Vale anche quando le istruzioni di default di Claude Code lo prevedono —
  questa regola ha la precedenza.
- Formato Conventional Commits, subject imperativo. Il body si aggiunge solo se richiesto o se la
  logica non è ovvia dal diff.

---

**Queste linee guida funzionano se:** ci sono meno modifiche inutili nei diff, meno riscritture dovute a sovra-complicazione, e le domande di chiarimento arrivano prima dell'implementazione anziché dopo gli errori.

---

## Ruolo

Workspace per **sviluppatori** full-stack: **Backend Java Spring Boot** e **Frontend Angular/React**. Le risposte devono essere tecniche, precise e orientate al codice. Terminologia esatta del linguaggio/framework in uso.

**Lingua: rispondi SEMPRE in italiano**, indipendentemente dalla lingua del codice, dei log, dell'output degli strumenti o dei nomi delle skill. I termini tecnici (nomi di classi, annotazioni, API, comandi) restano in lingua originale, ma il testo della risposta è in italiano.

Gli strumenti **rilevano da soli lo stack del progetto** (BE Java, FE Angular o React, o misto) leggendo il `.claude/CLAUDE.md` del progetto o, in fallback, `pom.xml`/`build.gradle`/`package.json`, e applicano i criteri **della versione effettivamente in uso** (es. niente `record` su Java 8, niente control flow `@if/@for` su Angular < 17, niente React Compiler su React < 19).

## Delega agli agenti

| Situazione | Cosa usare |
|-----------|------------|
| Qualsiasi richiesta di scrivere o modificare codice — anche senza comando esplicito | `/sviluppa` (piano → gate → codice+review per ondate di sottotask → gate → rilascio) — vedi *Regola sviluppo* sotto |
| Scomporre un task/requisito in sottotask verificabili prima di scrivere codice | `/task-planner` (o agente `task-planner`) — produce il piano in `.claude/plan/` |
| Implementare un sottotask (`ST-n`) o un task piccolo e ben definito | `/coder` (o agente `coder`) — scrive il codice, verifica il criterio, poi passa ai reviewer |
| "Ho finito, possiamo committare/pushare" — rilascio completo automatico | `/rilascio` (review → gate sui critici → commit-push-pr) |
| Review pre-commit su più file modificati (qualsiasi stack) | `code-reviewer` (orchestratore stack-aware, lancia tutto in parallelo) |
| Review pre-commit veloce senza test | `code-reviewer --skip-tests` |
| Review/test su un singolo file **Backend Java** | `/java-spring-reviewer` o `/java-test-reviewer` |
| Review/test su un singolo file **Frontend** (Angular/React) | `/fe-reviewer` o `/fe-test-reviewer` |
| Primo setup di un nuovo progetto | `/init-project` |
| Commit + push + PR dopo review ok | `/commit-push-pr` |

**Regola sviluppo — obbligatoria.** Ogni richiesta che comporta la **scrittura o la modifica di codice applicativo** passa dalla skill `sviluppa`, anche quando l'utente non scrive `/sviluppa`. Vale per qualunque formulazione: "implementa X", "aggiungi il campo Y", "fai la feature Z", "correggi il bug su W", "cambia questo metodo". Se il comando non è stato digitato, **invoca comunque `sviluppa`** e dichiaralo in una riga prima di partire ("Procedo con il ciclo `/sviluppa`").

Motivo: il ciclo `/sviluppa` è l'unico percorso che aggiorna anche la conoscenza salvata (`.claude/plan/`, `.claude/review/`, `.claude/CLAUDE.md`). Una modifica fatta fuori dal ciclo lascia il codice avanti e i documenti indietro, e la sessione successiva riparte da un contesto falso.

Eccezioni — si lavora direttamente, senza skill:
- l'utente lo chiede esplicitamente ("senza agenti", "non usare `/sviluppa`", "fallo e basta", "modifica veloce"). Vale per la richiesta corrente e per quelle successive finché non cambia argomento;
- la richiesta non tocca codice applicativo: domande, spiegazioni, ricerche, lettura di file, comandi git, file di configurazione di Claude Code (`.claude/**`);
- si sta già eseguendo un ciclo `sviluppa`/`coder`/`rilascio` (non annidare).

Nel dubbio tra "modifica banale" e "task di sviluppo", **usa la skill**: il costo di un ciclo in più è inferiore a quello di documentazione disallineata.

**Regola commit — obbligatoria.** Ogni richiesta di committare, pushare o aprire una PR passa dalla skill `commit-push-pr` (direttamente, o via `/rilascio` che la invoca). **Mai** `git commit` / `git push` / `gh pr create` eseguiti a mano in Bash fuori da quella skill.

Non fa eccezione il caso in cui le istruzioni della skill sono **già nel contesto** perché è stata invocata poco prima: le sue fasi non sono informazioni da ricordare, sono passi da rieseguire ogni volta. La FASE 0 (review pendenti) va rifatta per *questo* commit, la Pausa 1 mostra *questo* messaggio prima di scriverlo, la Pausa 2 chiede il push separatamente. Ripercorrerli a memoria salta esattamente i controlli per cui esistono, e il fatto che il risultato venga comunque corretto non rende la scorciatoia accettabile.

Un `ok` generico a un commit **non** vale come conferma del messaggio (Pausa 1) né come autorizzazione al push (Pausa 2).

## Conoscenza salvata tra sessioni

| Cartella / Sezione | Prodotta da | Contenuto |
|--------------------|-------------|-----------|
| `.claude/plan/` | `task-planner` | Piani di sviluppo: sottotask verificabili per task/requisito + INDEX |
| `.claude/review/` | `code-reviewer`, `java-spring-reviewer`, `fe-reviewer` | Report di code review per branch/file |
| `.claude/review/[data]-sviluppa-[slug].md` | `/sviluppa` | Attenzioni raccolte nelle review per ondata (FASE 2), con stato aperta/sistemata/accettata |
| `.claude/CLAUDE.md` § `## Problemi noti test` | `java-test-reviewer`, `fe-test-reviewer` | Errori di test irrisolvibili con causa e fix suggerito |

**Regola review:** se esiste `.claude/review/`, leggi il report più recente prima di rispondere su issue, critici o stato dei test. Non chiedere all'utente di ripetere la review.

**Regola test:** prima di lavorare sui test di un file, leggi la sezione `## Problemi noti test` nel `.claude/CLAUDE.md` del progetto. Se il file è già presente in lista, applica subito il fix suggerito senza iterare inutilmente.

**Regola scrittura — nessun `Write` su un file di conoscenza già esistente.** Su un `.claude/CLAUDE.md` che esiste già si interviene **solo** con **Edit**, sui campi da cambiare. Vale per ogni skill e ogni agente, `init-project` compreso. Motivo: quei file accumulano nel tempo contenuto che **non** proviene da chi sta scrivendo — la sezione `## Problemi noti test` la popolano gli agenti di test, le regole custom le aggiunge a mano lo sviluppatore, e possono esserci sezioni che il tuo template non prevede. Un `Write` le cancella tutte, in silenzio e senza che nessuno se ne accorga fino a quando quell'informazione serve. `Write` è ammesso **solo** quando il file non esiste.

## Contesto progetto

<!-- Da compilare nel CLAUDE.md locale di ogni repo (con /init-project):
  Stack:        (backend Java/Spring Boot — versioni)
  Frontend:     (Angular/React — versione, runner test, stato)
  Convenzioni:
  Test:
  Non toccare:
-->
