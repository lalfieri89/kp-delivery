---
name: java-test-reviewer
description: Gestisce l'intero ciclo dei test per una classe Java Spring Boot. Analizza se esistono test, li genera se mancano, li revisiona se esistono, e alla fine indica i gap rimasti. Usare quando si vuole aggiungere o verificare i test di una classe esistente.
version: 1.3.0
disable-model-invocation: true
argument-hint: "[percorso file opzionale]"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

Analizza il file `$ARGUMENTS` (se non specificato, usa il file aperto nell'IDE).

Segui questo flusso in ordine.

---

## FASE 0 — Lettura contesto progetto e problemi noti

Cerca il file `.claude/CLAUDE.md` nella root del progetto (la directory che contiene `pom.xml` o `build.gradle`). Se esiste, leggilo ed estrai:

Dalla sezione `## Contesto progetto`:
- **Stack** — versione Spring Boot (determina `@MockitoBean` vs `@MockBean`), versione Java, DB
- **Convenzioni** — naming dei metodi di test
- **Test** — framework aggiuntivi dichiarati (Testcontainers, AssertJ, WireMock)
- **Non toccare** — cartelle da escludere dalla ricerca dei file di test

Dalla sezione `## Problemi noti test`:
- Cerca entry corrispondenti alla classe che stai analizzando
- Se trovi un problema noto per questa classe: mostralo all'utente, applica subito il fix suggerito, salta le prime iterazioni del loop (parti già dalla soluzione)

Usa questi valori per sovrascrivere i default. Se il file non esiste o le sezioni sono assenti, procedi con i default.

---

## FASE 1 — Analisi iniziale

1. Leggi la classe sorgente per intero
2. Identifica il layer (Controller, Service, Repository, ecc.)
3. Elenca tutti i metodi pubblici con una breve descrizione
4. Cerca il file di test corrispondente in `src/test/java/` nello stesso package

---

## FASE 2 — Generazione test (se mancano o sono incompleti)

Se non esiste una classe di test o i test coprono meno del 70% dei metodi pubblici, genera i test mancanti.

**Stack obbligatorio in base al layer:**

- **Service** → `@ExtendWith(MockitoExtension.class)`, mock di tutti i repository e service iniettati
- **Controller** → `@WebMvcTest(NomeController.class)` + `MockMvc`, mock del service con `@MockitoBean` (Spring Boot ≥ 3.4; usare `@MockBean` solo per versioni precedenti)
- **Repository** → `@DataJpaTest`, database H2 in-memory, nessun mock (per test production-like usare Testcontainers con `@ServiceConnection`)

**Regole per i test:**

Per ogni metodo pubblico genera almeno 3 test:
1. **Happy path** — scenario normale con dati validi
2. **Edge case** — valore nullo, lista vuota, valore al limite
3. **Scenario di errore** — eccezione attesa, entità non trovata, dati non validi

**Convenzione nomi metodi:**
`dovrebbe_[risultatoAtteso]_quando_[condizione]()`

**Struttura base:**
```java
// Service unit test (puro, senza Spring context)
@ExtendWith(MockitoExtension.class)
@DisplayName("Test di NomeClasse")
class NomeClasseTest {

    @Mock
    NomeDipendenza nomeDipendenza;

    @InjectMocks
    NomeClasse nomeClasse;

    @BeforeEach
    void setUp() {
        // inizializzazione dati di test
    }

    @Test
    @DisplayName("Dovrebbe restituire X quando Y")
    void dovrebbe_restituireX_quando_Y() {
        // Arrange
        // Act
        // Assert (usa AssertJ: assertThat(...).isEqualTo(...))
    }
}

// Controller test — usa @MockitoBean (Spring Boot ≥ 3.4, sostituisce @MockBean)
@WebMvcTest(NomeController.class)
class NomeControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    NomeService nomeService;
}
```

Scrivi il file generato in `src/test/java/` nel package corrispondente alla classe testata.

---

## FASE 3 — Revisione test esistenti

Se esistono già dei test, analizzane la qualità controllando:

1. **Copertura degli scenari** — tutti i metodi pubblici hanno almeno un test? Mancano edge case o scenari di errore?
2. **Qualità delle assertion** — le assertion verificano risultati reali? (no `assertTrue(true)`, no assert solo sul tipo)
3. **Uso corretto dei mock** — i mock simulano comportamenti realistici? Non si sta testando l'implementazione invece del comportamento?
4. **Isolamento** — ogni test è indipendente dagli altri? Dipendenze condivise gestite correttamente in `@BeforeEach`?
5. **Naming** — i nomi dei test descrivono chiaramente il comportamento atteso?
6. **Struttura Arrange-Act-Assert** — il corpo dei test è leggibile e ben organizzato?

Per ogni problema trovato:
- **Livello:** [CRITICO | ATTENZIONE | INFO]
- **Test:** nome del metodo di test
- **Problema:** descrizione in italiano
- **Soluzione:** come correggerlo con esempio

---

## FASE 4 — Esecuzione test, fix iterativo e riepilogo

### 4.1 — Esecuzione iniziale

Esegui i test della classe, isolando solo la classe di test generata/revisionata.

**Maven:**
```bash
mvn test -Dtest=NomeClasseTest -Dsurefire.failIfNoSpecifiedTests=false
```
Non aggiungere `-pl .`: limiterebbe l'esecuzione al solo modulo radice, e in un progetto **multi-modulo** la classe di test è quasi sempre in un sottomodulo — il test non verrebbe mai eseguito. Se il progetto è multi-modulo e conosci il modulo che contiene la classe, esegui il comando da lì (o aggiungi `-pl <nome-modulo>`).

**Gradle:**
```bash
./gradlew test --tests NomeClasseTest
```
(su Windows senza Git Bash: `gradlew.bat test --tests NomeClasseTest`)

Rileva il build tool dalla presenza di `pom.xml` (Maven) o `build.gradle`/`build.gradle.kts` (Gradle) nella root o nel modulo. Se nessuno dei due comandi è applicabile, adatta al comando dichiarato nel `CLAUDE.md` di progetto o nella documentazione del repo.

### 4.2 — Loop fix/rilancio

**Ripeti questo ciclo finché tutti i test passano (o fino a 5 iterazioni massime):**

1. Leggi l'output del test
2. Per ogni test fallito:
   - Identifica la causa: asserzione sbagliata, mock non configurato correttamente, dato di test errato, firma del metodo cambiata
   - Correggi il file di test (non toccare mai il sorgente della classe testata)
3. Rilancia i test
4. Se tutti i test passano → esci dal loop

**Conta le iterazioni consumate** e riportale nel riepilogo finale come `Iterazioni: N/5` (`1/5` = passato al primo colpo, `0/5` = nessuna esecuzione). Serve a capire se la soglia di 5 è tarata bene o se sta mascherando test scritti male.
5. Se dopo 5 iterazioni ci sono ancora fallimenti → documenta i test irrisolvibili nella sezione finale e spiega perché. Aggiorna `.claude/CLAUDE.md` del progetto con il tool **Edit** (mai `Write`: riscriverebbe l'intero file di contesto). Per `[YYYY-MM-DD]` usa la data odierna che trovi già nel tuo contesto di sessione, non serve ricavarla con Bash. Leggilo prima con **Read**:
   - se la sezione `## Problemi noti test` non esiste, usa `Edit` per aggiungerla in coda al file con la prima entry;
   - se esiste, usa `Edit` per aggiungere la riga alla sezione esistente, senza toccare il resto del file:
   ```markdown
   - [YYYY-MM-DD] `NomeClasseTest` — errore: [messaggio sintetico] — causa probabile: [spiegazione] — fix suggerito: [soluzione]
   ```
   Questo evita di ripetere le stesse iterazioni nella sessione successiva.

   **Se invece tutti i test passano** e la classe era in `## Problemi noti test`, usa **Edit** per rimuovere solo quella riga dal `.claude/CLAUDE.md` — il problema è risolto e non deve accumularsi come entry obsoleta.

### 4.3 — Gap analysis e riepilogo finale

Produci una tabella con la copertura finale:

| Metodo | Testato | Scenari coperti | Priorità gap |
|--------|---------|-----------------|--------------|
| nomeMetodo() | SI / NO | happy path, edge case | ALTA / MEDIA / BASSA |

**Priorità gap:**
- **ALTA** — logica di calcolo, validazione dati, operazioni critiche (es. salvataggi, calcoli finanziari)
- **MEDIA** — operazioni CRUD standard, mapping DTO
- **BASSA** — getter/setter semplici, utility di bassa complessità

**Stima effort** per colmare i gap rimanenti: S (< 1h), M (1-3h), L (> 3h)

Concludi con un **GIUDIZIO FINALE**: COPERTURA BUONA / COPERTURA PARZIALE / COPERTURA INSUFFICIENTE
