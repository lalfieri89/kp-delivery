#!/usr/bin/env bash
# install.sh — Installa le skill e gli agenti Claude Code aziendali
# Compatibile con macOS e Linux

set -e

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SKILLS="$SCRIPT_DIR/skills"
SOURCE_AGENTS="$SCRIPT_DIR/agents"
SOURCE_CLAUDE="$SCRIPT_DIR/CLAUDE.md"

PKG_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "?")

echo "=== Installazione skill Claude Code aziendali (v$PKG_VERSION) ==="
echo ""

# Verifica che Claude Code sia installato
if ! command -v claude &>/dev/null; then
  echo "ATTENZIONE: il comando 'claude' non è stato trovato nel PATH."
  echo "Assicurati di aver installato Claude Code prima di procedere."
  echo "https://docs.anthropic.com/it/docs/claude-code/getting-started"
  echo ""
fi

# Verifica che Node.js sia installato (richiesto dall'hook SessionStart e dal merge)
if ! command -v node &>/dev/null; then
  echo "ATTENZIONE: il comando 'node' non è stato trovato nel PATH."
  echo "Node.js è richiesto da Claude Code e dall'hook SessionStart."
  echo ""
fi

# Crea le directory se non esistono
mkdir -p "$SKILLS_DIR"
mkdir -p "$AGENTS_DIR"

INSTALLED=0
SKIPPED=0

# Copia CLAUDE.md nella cartella .claude locale
echo "Installazione CLAUDE.md..."
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  read -r -p "  CLAUDE.md esiste già. Sovrascrivere? [s/N] " answer
  case "$answer" in
    [sS])
      cp "$SOURCE_CLAUDE" "$CLAUDE_DIR/CLAUDE.md"
      echo "  ✓ CLAUDE.md (aggiornato)"
      INSTALLED=$((INSTALLED + 1))
      ;;
    *)
      echo "  - CLAUDE.md (saltato)"
      SKIPPED=$((SKIPPED + 1))
      ;;
  esac
else
  cp "$SOURCE_CLAUDE" "$CLAUDE_DIR/CLAUDE.md"
  echo "  ✓ CLAUDE.md (installato)"
  INSTALLED=$((INSTALLED + 1))
fi
echo ""

# Installa settings.json (hook SessionStart + PreToolUse + UserPromptSubmit) — senza sovrascrivere config esistente
echo "Installazione settings.json (hook SessionStart + PreToolUse + UserPromptSubmit)..."
SOURCE_SETTINGS="$SCRIPT_DIR/.claude/settings.json"
MERGE_SCRIPT="$SCRIPT_DIR/.claude/merge-settings.js"
DEST_SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SOURCE_SETTINGS" ]; then
  if [ -f "$DEST_SETTINGS" ]; then
    if command -v node &>/dev/null; then
      echo "  settings.json già presente: unisco gli hook del toolkit preservando la tua configurazione..."
      if node "$MERGE_SCRIPT" "$SOURCE_SETTINGS" "$DEST_SETTINGS"; then
        INSTALLED=$((INSTALLED + 1))
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    else
      echo "  - settings.json già presente e 'node' non disponibile: NON sovrascritto."
      echo "    Per abilitare gli hook del toolkit, unisci a mano il contenuto di:"
      echo "    $SOURCE_SETTINGS"
      SKIPPED=$((SKIPPED + 1))
    fi
  else
    cp "$SOURCE_SETTINGS" "$DEST_SETTINGS"
    echo "  ✓ settings.json (installato)"
    INSTALLED=$((INSTALLED + 1))
  fi
fi
echo ""

# Installa le skill (directory)
echo "Installazione skill..."
for skill_dir in "$SOURCE_SKILLS"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  dest="$SKILLS_DIR/$skill_name"

  if [ -d "$dest" ]; then
    read -r -p "  La skill '$skill_name' esiste già. Sovrascrivere? [s/N] " answer
    case "$answer" in
      [sS])
        rm -rf "$dest"
        cp -r "$skill_dir" "$dest"
        echo "  ✓ $skill_name (aggiornata)"
        INSTALLED=$((INSTALLED + 1))
        ;;
      *)
        echo "  - $skill_name (saltata)"
        SKIPPED=$((SKIPPED + 1))
        ;;
    esac
  else
    cp -r "$skill_dir" "$dest"
    echo "  ✓ $skill_name (installata)"
    INSTALLED=$((INSTALLED + 1))
  fi
done

# Installa le skill file singoli (es. skill standalone senza cartella dedicata)
for skill_file in "$SOURCE_SKILLS"/*.md; do
  [ -f "$skill_file" ] || continue
  skill_name=$(basename "$skill_file")
  dest="$SKILLS_DIR/$skill_name"

  if [ -f "$dest" ]; then
    read -r -p "  La skill '$skill_name' esiste già. Sovrascrivere? [s/N] " answer
    case "$answer" in
      [sS])
        cp "$skill_file" "$dest"
        echo "  ✓ $skill_name (aggiornata)"
        INSTALLED=$((INSTALLED + 1))
        ;;
      *)
        echo "  - $skill_name (saltata)"
        SKIPPED=$((SKIPPED + 1))
        ;;
    esac
  else
    cp "$skill_file" "$dest"
    echo "  ✓ $skill_name (installata)"
    INSTALLED=$((INSTALLED + 1))
  fi
done

# Installa gli agenti
echo ""
echo "Installazione agenti..."
for agent_file in "$SOURCE_AGENTS"/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name=$(basename "$agent_file")
  dest="$AGENTS_DIR/$agent_name"

  if [ -f "$dest" ]; then
    read -r -p "  L'agente '$agent_name' esiste già. Sovrascrivere? [s/N] " answer
    case "$answer" in
      [sS])
        cp "$agent_file" "$dest"
        echo "  ✓ $agent_name (aggiornato)"
        INSTALLED=$((INSTALLED + 1))
        ;;
      *)
        echo "  - $agent_name (saltato)"
        SKIPPED=$((SKIPPED + 1))
        ;;
    esac
  else
    cp "$agent_file" "$dest"
    echo "  ✓ $agent_name (installato)"
    INSTALLED=$((INSTALLED + 1))
  fi
done

echo ""
echo "Installazione completata: $INSTALLED installati, $SKIPPED saltati."
echo ""
echo "Skill disponibili in Claude Code:"
echo "  /init-project"
echo "  /sviluppa <task o requisito>   (ciclo completo: piano -> codice -> review -> rilascio)"
echo "  /task-planner <task o requisito>   (piano di sottotask verificabili)"
echo "  /coder <ST-n o task>   (implementa un sottotask e verifica il criterio)"
echo "  /rilascio [branch] [--skip-tests]   (review + commit automatici)"
echo "  /commit-push-pr [--no-push] [--draft-pr] [--squash]"
echo "  /java-spring-reviewer <percorso-file>   (Backend Java)"
echo "  /java-test-reviewer <percorso-file>     (Backend Java)"
echo "  /fe-reviewer <percorso-file>            (Frontend Angular/React)"
echo "  /fe-test-reviewer <percorso-file>       (Frontend Angular/React)"
echo "  /doc-search \"termine\"    — cerca in .claude/review/, .claude/plan/, docs/"
echo ""
echo "Per disinstallare: elimina a mano le skill/gli agenti elencati sopra da"
echo "  $SKILLS_DIR e $AGENTS_DIR"
echo "Gli hook del toolkit in $CLAUDE_DIR/settings.json e le righe corrispondenti in $CLAUDE_DIR/CLAUDE.md vanno rimossi manualmente."
