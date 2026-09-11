---
name: fe-test-reviewer
description: Gestisce l'intero ciclo dei test per un file Frontend (Angular o React). Rileva framework, versione e test runner dal progetto, genera i test se mancano, revisiona quelli esistenti, li esegue con il comando corretto e indica i gap. Adatta lo stack di test alla versione in uso.
version: 1.0.0
disable-model-invocation: true
argument-hint: "[percorso file opzionale]"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

Analizza il file `$ARGUMENTS` (se non specificato, usa il file aperto nell'IDE) seguendo il flusso FASE 0→4.

---

## FASE 0 — Contesto, framework, versione, runner e problemi noti

1. Cerca `.claude/CLAUDE.md` nella root (directory con `package.json`). Se esiste, dalla sezione `## Contesto progetto` → `**Frontend:**` estrai framework, versione, runner di test e convenzioni; dalla sezione `## Problemi noti test` cerca un'entry per il file che stai analizzando (se c'è: mostrala, applica subito il fix, salta le prime iterazioni del loop).

2. Se manca, **rileva dal progetto**:
   - Framework: `@angular/core` → **Angular**; `react`/`react-dom` → **React** (versione = valore della dipendenza)
   - **Runner di test**:
     - Angular: guarda `angular.json` (`test.builder`) e `package.json` → **Karma + Jasmine** (`karma`, `jasmine-core`) | **Jest** (`jest`, `jest-preset-angular`) | **Vitest** (`@analogjs/vitest-angular` o config). Da Angular 20 il default CLI è Vitest; nei progetti più vecchi è quasi sempre Karma+Jasmine.
     - React: `package.json` → **Vitest** (`vitest`) | **Jest** (`jest`). Libreria di asserzione UI: **React Testing Library** (`@testing-library/react`).
   - Comando di esecuzione: cerca lo script in `package.json` (`test`, `test:unit`); fallback per Angular `ng test --watch=false --browsers=ChromeHeadless`, per Vitest `npx vitest run <file>`, per Jest `npx jest <file>`.

3. **Se non riesci a determinare framework o versione**, dichiaralo e non proporre costrutti version-gated (vedi sotto).

### REGOLA versione (test)
Non proporre API non disponibili nella versione/runner del progetto. Esempi: `provideZonelessChangeDetection` solo Angular ≥ 18; `signal` testing solo ≥16; su Karma+Jasmine la sintassi è `jasmine.createSpy`/`spyOn`, su Jest/Vitest è `jest.fn()`/`vi.fn()`. Usa la sintassi del runner effettivamente in uso.

---

## FASE 1 — Analisi iniziale

1. Leggi il file sorgente per intero
2. Identifica il tipo (componente, servizio/hook, store, guard/route, util)
3. Elenca le unità testabili: metodi pubblici / funzioni esportate / comportamenti osservabili del componente (render, interazioni, output)
4. Cerca il file di test corrispondente:
   - Angular: `*.spec.ts` nello stesso folder
   - React: `*.test.tsx`/`*.test.ts` o `*.spec.tsx` (o cartella `__tests__/`)

---

## FASE 2 — Generazione test (se mancano o coprono < 70% delle unità)

Applica lo **stack del progetto** rilevato in FASE 0. Per ogni unità genera almeno 3 casi: **happy path**, **edge case** (null/vuoto/limite), **errore**.

### Angular
- **Componente**: `TestBed.configureTestingModule({...})` con **solo** le dichiarazioni/provider necessari (più veloce); per componenti standalone usare `imports: [NomeComponent]`. Preferire un approccio **user-centric** con [Angular Testing Library](https://testing-library.com/docs/angular-testing-library/intro/) (`render`, `screen`, query per ruolo) dove il progetto la usa.
- **Servizio**: istanziare via `TestBed.inject(NomeService)`; HTTP testato con `HttpTestingController` (`provideHttpClientTesting`).
- **Async**: `fakeAsync` + `tick()` oppure `waitFor`/`findBy*`; spie con `spyOn`/`jasmine.createSpy` (Karma) o `jest.fn()`/`vi.fn()` (Jest/Vitest).

```ts
// Esempio (Angular Testing Library + runner del progetto)
import { render, screen } from '@testing-library/angular';
import userEvent from '@testing-library/user-event';

it('dovrebbe mostrare il messaggio quando si clicca il bottone', async () => {
  await render(SalutoComponent, { componentInputs: { nome: 'Anna' } });
  await userEvent.click(screen.getByRole('button', { name: /saluta/i }));
  expect(screen.getByText(/ciao anna/i)).toBeInTheDocument();
});
```

### React (React Testing Library + Vitest/Jest)
- Render con `render()`, query **accessibili** (`getByRole`, `getByLabelText`) — evitare `getByTestId` se non necessario.
- Interazioni con `@testing-library/user-event` (non `fireEvent` dove possibile).
- Async: `findBy*` / `await waitFor(...)` per effetti e fetch.
- Mock **giudiziosi**: solo ciò che serve a isolare l'unità (`vi.fn()`/`vi.mock()` con Vitest, `jest.fn()`/`jest.mock()` con Jest). Vitest non fa automock come Jest: mocka manualmente.

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

test('mostra il conteggio aggiornato dopo il click', async () => {
  render(<Contatore iniziale={0} />);
  await userEvent.click(screen.getByRole('button', { name: /incrementa/i }));
  expect(screen.getByText('1')).toBeInTheDocument();
});
```

Scrivi il file di test accanto al sorgente, con l'estensione e il naming del progetto.

---

## FASE 3 — Revisione test esistenti

Controlla:
1. **Comportamento, non implementazione** — i test verificano cosa vede/fa l'utente, non i dettagli interni? Un refactoring senza cambi di comportamento non deve romperli.
2. **Query accessibili** — `getByRole`/`getByLabelText` preferiti a selettori CSS/testid fragili.
3. **Copertura scenari** — happy path, edge case, errore per ogni unità.
4. **Async gestito** — niente assert prima che lo stato si aggiorni; uso di `findBy`/`waitFor`/`fakeAsync`.
5. **Mock corretti** — realistici e minimi; nessun over-mock che testa il mock invece del codice.
6. **Isolamento** — test indipendenti; reset di mock/timer tra i test (`afterEach`, `vi.clearAllMocks`).
7. **Naming e struttura AAA** — Arrange-Act-Assert leggibile; nomi che descrivono il comportamento.

Per ogni problema: **Livello** [CRITICO | ATTENZIONE | INFO] · **Test** (nome) · **Problema** · **Soluzione**.

---

## FASE 4 — Esecuzione, fix iterativo e riepilogo

### 4.1 — Esecuzione
Lancia il comando rilevato in FASE 0, isolando il file di test. Esempi:
```bash
# Angular + Karma
ng test --watch=false --browsers=ChromeHeadless --include='**/nome.spec.ts'
# Vitest
npx vitest run percorso/nome.test.tsx
# Jest
npx jest percorso/nome.test.tsx
```
Se il progetto non parte o il comando non è applicabile, adattalo agli script in `package.json`.

### 4.2 — Loop fix/rilancio (max 5 iterazioni)
Identifica la causa (assert errato, mock non configurato, async non atteso, query sbagliata) → correggi **solo il file di test**, mai il sorgente → rilancia.

**Conta le iterazioni consumate** e riportale nel riepilogo finale come `Iterazioni: N/5` (`1/5` = passato al primo colpo, `0/5` = nessuna esecuzione). Serve a capire se la soglia di 5 è tarata bene o se sta mascherando test scritti male.

Se dopo 5 iterazioni restano fallimenti irrisolvibili, aggiorna `.claude/CLAUDE.md` del progetto con il tool **Edit** (mai `Write`: riscriverebbe l'intero file di contesto). Per `[YYYY-MM-DD]` usa la data odierna che trovi già nel tuo contesto di sessione, non serve ricavarla con Bash. Leggilo prima con **Read**:
- se la sezione `## Problemi noti test` non esiste, usa `Edit` per aggiungerla in coda al file con la prima entry;
- se esiste, usa `Edit` per aggiungere la riga alla sezione esistente, senza toccare il resto del file:
```markdown
- [YYYY-MM-DD] `nome.spec` — errore: [messaggio sintetico] — causa probabile: [spiegazione] — fix suggerito: [soluzione]
```
Se invece tutti i test passano e il file era in `## Problemi noti test`, usa **Edit** per rimuovere solo quella riga.

### 4.3 — Gap analysis
| Unità | Testata | Scenari coperti | Priorità gap |
|-------|---------|-----------------|--------------|
| nomeFunzione/comportamento | SI / NO | happy, edge | ALTA / MEDIA / BASSA |

**Priorità:** ALTA = logica/calcolo/validazione, interazioni critiche · MEDIA = render con props, eventi standard · BASSA = markup statico, util semplici.
**Effort:** S (< 1h), M (1-3h), L (> 3h).

Concludi con: **COPERTURA BUONA** / **COPERTURA PARZIALE** / **COPERTURA INSUFFICIENTE**.

---

## Regole importanti
- Usa **sempre** la sintassi del runner effettivamente in uso (Jasmine vs Jest vs Vitest)
- Non proporre API non supportate dalla versione del framework
- Non toccare mai il file sorgente — solo i test
- Test user-centric: comportamento osservabile, non dettagli interni
