@echo off
REM install.bat - Installa le skill e gli agenti Claude Code aziendali
REM Compatibile con Windows

setlocal enabledelayedexpansion

set "SKILLS_DIR=%USERPROFILE%\.claude\skills"
set "AGENTS_DIR=%USERPROFILE%\.claude\agents"
set "SOURCE_SKILLS=%~dp0skills"
set "SOURCE_AGENTS=%~dp0agents"

set "PKG_VERSION=?"
if exist "%~dp0VERSION" set /p PKG_VERSION=<"%~dp0VERSION"

echo === Installazione skill Claude Code aziendali (v%PKG_VERSION%) ===
echo.

REM Verifica che Claude Code sia installato
where claude >nul 2>&1
if errorlevel 1 (
    echo ATTENZIONE: il comando 'claude' non e' stato trovato nel PATH.
    echo Assicurati di aver installato Claude Code prima di procedere.
    echo https://docs.anthropic.com/it/docs/claude-code/getting-started
    echo.
)

REM Verifica che Node.js sia installato (richiesto dall'hook SessionStart e dal merge)
where node >nul 2>&1
if errorlevel 1 (
    echo ATTENZIONE: il comando 'node' non e' stato trovato nel PATH.
    echo Node.js e' richiesto da Claude Code e dall'hook SessionStart.
    echo.
)

REM Verifica che git sia installato (richiesto da /commit-push-pr e /rilascio)
where git >nul 2>&1
if errorlevel 1 (
    echo ATTENZIONE: il comando 'git' non e' stato trovato nel PATH.
    echo git e' richiesto da /commit-push-pr e /rilascio.
    echo.
)

REM Verifica che gh CLI sia installato (richiesto per la creazione PR)
where gh >nul 2>&1
if errorlevel 1 (
    echo ATTENZIONE: il comando 'gh' ^(GitHub CLI^) non e' stato trovato nel PATH.
    echo gh e' richiesto solo se vuoi creare Pull Request da /commit-push-pr.
    echo.
)

set "CLAUDE_DIR=%USERPROFILE%\.claude"
set "SOURCE_CLAUDE=%~dp0CLAUDE.md"

REM Crea le directory se non esistono
if not exist "%SKILLS_DIR%" mkdir "%SKILLS_DIR%"
if not exist "%AGENTS_DIR%" mkdir "%AGENTS_DIR%"

set INSTALLED=0
set SKIPPED=0

REM Copia CLAUDE.md nella cartella .claude locale
echo Installazione CLAUDE.md...
if exist "%CLAUDE_DIR%\CLAUDE.md" (
    set "answer="
    set /p "answer=  CLAUDE.md esiste gia'. Sovrascrivere? [s/N] "
    if /i "!answer!"=="s" (
        copy /Y "%SOURCE_CLAUDE%" "%CLAUDE_DIR%\CLAUDE.md" >nul
        echo   OK CLAUDE.md ^(aggiornato^)
        set /a INSTALLED+=1
    ) else (
        echo   - CLAUDE.md ^(saltato^)
        set /a SKIPPED+=1
    )
) else (
    copy /Y "%SOURCE_CLAUDE%" "%CLAUDE_DIR%\CLAUDE.md" >nul
    echo   OK CLAUDE.md ^(installato^)
    set /a INSTALLED+=1
)
echo.

REM Installa settings.json (hook SessionStart + PreToolUse + UserPromptSubmit) - senza sovrascrivere config esistente
echo Installazione settings.json (hook SessionStart + PreToolUse + UserPromptSubmit)...
set "SOURCE_SETTINGS=%~dp0.claude\settings.json"
set "MERGE_SCRIPT=%~dp0.claude\merge-settings.js"
set "DEST_SETTINGS=%CLAUDE_DIR%\settings.json"
if exist "%SOURCE_SETTINGS%" (
    if exist "%DEST_SETTINGS%" (
        echo   settings.json gia' presente: unisco gli hook del toolkit preservando la tua configurazione...
        node "%MERGE_SCRIPT%" "%SOURCE_SETTINGS%" "%DEST_SETTINGS%"
        if errorlevel 1 (
            echo   ERRORE: merge di settings.json fallito ^(node mancante o file non valido^). settings.json NON aggiornato.
            set /a SKIPPED+=1
        ) else (
            set /a INSTALLED+=1
        )
    ) else (
        copy /Y "%SOURCE_SETTINGS%" "%DEST_SETTINGS%" >nul
        echo   OK settings.json ^(installato^)
        set /a INSTALLED+=1
    )
)
echo.

REM Installa le skill (directory)
echo Installazione skill...
for /D %%d in ("%SOURCE_SKILLS%\*") do (
    set "skill_name=%%~nxd"
    set "dest=%SKILLS_DIR%\%%~nxd"

    if exist "!dest!" (
        set "answer="
        set /p "answer=  La skill '!skill_name!' esiste gia'. Sovrascrivere? [s/N] "
        if /i "!answer!"=="s" (
            xcopy /E /I /Y "%%d" "!dest!" >nul
            echo   OK !skill_name! ^(aggiornata^)
            set /a INSTALLED+=1
        ) else (
            echo   - !skill_name! ^(saltata^)
            set /a SKIPPED+=1
        )
    ) else (
        xcopy /E /I /Y "%%d" "!dest!" >nul
        echo   OK !skill_name! ^(installata^)
        set /a INSTALLED+=1
    )
)

REM Installa le skill file singoli (es. skill standalone senza cartella dedicata)
for %%f in ("%SOURCE_SKILLS%\*.md") do (
    set "skill_name=%%~nxf"
    set "dest=%SKILLS_DIR%\%%~nxf"

    if exist "!dest!" (
        set "answer="
        set /p "answer=  La skill '!skill_name!' esiste gia'. Sovrascrivere? [s/N] "
        if /i "!answer!"=="s" (
            copy /Y "%%f" "!dest!" >nul
            echo   OK !skill_name! ^(aggiornata^)
            set /a INSTALLED+=1
        ) else (
            echo   - !skill_name! ^(saltata^)
            set /a SKIPPED+=1
        )
    ) else (
        copy /Y "%%f" "!dest!" >nul
        echo   OK !skill_name! ^(installata^)
        set /a INSTALLED+=1
    )
)

REM Installa gli agenti
echo.
echo Installazione agenti...
for %%f in ("%SOURCE_AGENTS%\*.md") do (
    set "agent_name=%%~nxf"
    set "dest=%AGENTS_DIR%\%%~nxf"

    if exist "!dest!" (
        set "answer="
        set /p "answer=  L'agente '!agent_name!' esiste gia'. Sovrascrivere? [s/N] "
        if /i "!answer!"=="s" (
            copy /Y "%%f" "!dest!" >nul
            echo   OK !agent_name! ^(aggiornato^)
            set /a INSTALLED+=1
        ) else (
            echo   - !agent_name! ^(saltato^)
            set /a SKIPPED+=1
        )
    ) else (
        copy /Y "%%f" "!dest!" >nul
        echo   OK !agent_name! ^(installato^)
        set /a INSTALLED+=1
    )
)

echo.
echo Installazione completata: %INSTALLED% installati, %SKIPPED% saltati.
echo.
echo Skill disponibili in Claude Code:
echo   /init-project
echo   /sviluppa ^<task o requisito^>   ^(ciclo completo: piano -^> codice -^> review -^> rilascio^)
echo   /task-planner ^<task o requisito^>   ^(piano di sottotask verificabili^)
echo   /coder ^<ST-n o task^>   ^(implementa un sottotask e verifica il criterio^)
echo   /rilascio [branch] [--skip-tests]   ^(review + commit automatici^)
echo   /commit-push-pr [--no-push] [--draft-pr] [--squash]
echo   /java-spring-reviewer ^<percorso-file^>   ^(Backend Java^)
echo   /java-test-reviewer ^<percorso-file^>     ^(Backend Java^)
echo   /fe-reviewer ^<percorso-file^>            ^(Frontend Angular/React^)
echo   /fe-test-reviewer ^<percorso-file^>       ^(Frontend Angular/React^)
echo   /doc-search "termine"    - cerca in .claude/review/, .claude/plan/, docs/
echo.
echo Per disinstallare: elimina a mano le skill/gli agenti elencati sopra da
echo   %SKILLS_DIR% e %AGENTS_DIR%
echo Gli hook del toolkit in %CLAUDE_DIR%\settings.json e le righe corrispondenti in %CLAUDE_DIR%\CLAUDE.md vanno rimossi manualmente.
echo.
pause
