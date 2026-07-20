#!/usr/bin/env bash
#
# forgeKeyBindings.sh
#
# Reaplica a configuração do Forge definida abaixo.
# Edite os valores dentro de SETTINGS e rode o script sempre que quiser
# reimpor esse estado (ex: depois de uma atualização da extensão, reset,
# ou em uma nova máquina).
#
# Uso:
#   ./forgeKeyBindings.sh
#
# Se a extensão foi instalada via `make install` (build do source),
# defina a variável SCHEMADIR antes de rodar, ou exporte-a no seu shell:
#   SCHEMADIR=~/.local/share/gnome-shell/extensions/forge@jmmaranan.com/schemas ./forgeKeyBindings.sh

set -euo pipefail

SCHEMA_MAIN="org.gnome.shell.extensions.forge"
SCHEMA_KEYS="org.gnome.shell.extensions.forge.keybindings"
SCHEMADIR="${SCHEMADIR:-}"

# =============================================================================
# EDITE AQUI: chave = valor (no formato que o gsettings espera)
#   - arrays de atalhos:      "['<Alt>Down', '<Alt>j']"
#   - arrays vazios (as):     "@as []"
#   - strings:                "'rgb(203,166,247)'"   (aspas simples fazem parte do valor)
#   - booleanos:               true / false
#   - números (uint32/int):    3 / 0 / 15
# =============================================================================
declare -A SETTINGS_MAIN=(
  # ----- Aparência / Comportamento -----
  [focus-border-toggle]="true"
  [focus-border-size]="2"
  [focus-border-color]="'rgb(203, 166, 247)'"
  [split-border-toggle]="true"
  [split-border-color]="'rgba(255, 246, 108, 1)'"
  [window-gap-size]="4"
  [window-gap-size-increment]="1"
  [window-gap-hidden-on-single]="false"
  [resize-amount]="15"

  # ----- Layout -----
  [primary-layout-mode]="'tiling'"
  [tiling-mode-enabled]="true"
  [stacked-tiling-mode-enabled]="true"
  [tabbed-tiling-mode-enabled]="true"
  [auto-split-enabled]="true"
  [auto-exit-tabbed]="true"
  [dnd-center-layout]="'tabbed'"

  # ----- Floating -----
  [float-always-on-top-enabled]="true"

  # ----- Foco / Mouse -----
  [move-pointer-focus-enabled]="false"
  [focus-on-hover-enabled]="false"
  [preview-hint-enabled]="true"

  # ----- Decoração -----
  [showtab-decoration-enabled]="true"

  # ----- Workspace -----
  [workspace-skip-tile]="''"

  # ----- Quick Settings -----
  [quick-settings-enabled]="true"

  # ----- Desenvolvimento -----
  [log-level]="0"
  [logging-enabled]="false"
)

declare -A SETTINGS_KEYS=(
  # ----- Navegação entre janelas (Vim-like) -----
  [window-focus-left]="['<Alt>h']"
  [window-focus-down]="['<Alt>j']"
  [window-focus-up]="['<Alt>k']"
  [window-focus-right]="['<Alt>l']"

  # ----- Mover janelas -----
  [window-move-left]="['<Shift><Alt>h']"
  [window-move-down]="['<Shift><Alt>j']"
  [window-move-up]="['<Shift><Alt>k']"
  [window-move-right]="['<Shift><Alt>l']"

  # ----- Trocar (swap) janelas -----
  [window-swap-left]="['']"
  [window-swap-down]="['']"
  [window-swap-up]="['']"
  [window-swap-right]="['']"

  # ----- Janela flutuante -----
  [window-toggle-float]="['']"
  [window-toggle-always-float]="['']"

  # ----- Última janela ativa -----
  [window-swap-last-active]="['']"

  # ----- Layout: Split -----
  [con-split-layout-toggle]="['']"
  [con-split-horizontal]="['']"
  [con-split-vertical]="['']"

  # ----- Layout: Stacked / Tabbed -----
  [con-stacked-layout-toggle]="['']"
  [con-tabbed-layout-toggle]="['']"
  [con-tabbed-showtab-decoration-toggle]="['']"

  # ----- Foco border -----
  [focus-border-toggle]="['']"

  # ----- Gap -----
  [window-gap-size-increase]="['']"
  [window-gap-size-decrease]="['']"

  # ----- Tiling on/off -----
  [prefs-tiling-toggle]="['']"
  [workspace-active-tile-toggle]="['']"
  [prefs-open]="['']"

  # ----- Snap (um terço / dois terços) -----
  [window-snap-one-third-left]="['']"
  [window-snap-two-third-left]="['']"
  [window-snap-one-third-right]="['']"
  [window-snap-two-third-right]="['']"
  [window-snap-center]="['']"

  # ----- Redimensionar -----
  [window-resize-left-increase]="['']"
  [window-resize-left-decrease]="['']"
  [window-resize-right-increase]="['']"
  [window-resize-right-decrease]="['']"
  [window-resize-top-increase]="['']"
  [window-resize-top-decrease]="['']"
  [window-resize-bottom-increase]="['']"
  [window-resize-bottom-decrease]="['']"

  # ----- Mod mask para drag-and-drop -----
  [mod-mask-mouse-tile]="'None'"
)
# =============================================================================

GSETTINGS=(gsettings)
if [[ -n "$SCHEMADIR" ]]; then
  GSETTINGS=(gsettings --schemadir "$SCHEMADIR")
fi

fail=0

apply_settings() {
  local schema="$1"
  local -n settings="$2"
  local label="$3"

  echo ""
  echo "--- $label (schema: $schema) ---"

  for key in "${!settings[@]}"; do
    value="${settings[$key]}"
    if "${GSETTINGS[@]}" set "$schema" "$key" "$value" 2>/tmp/forge-err.log; then
      printf '  ✔ %-38s %s\n' "$key" "$value"
    else
      printf '  ✘ %-38s FALHOU (%s)\n' "$key" "$(cat /tmp/forge-err.log)"
      fail=1
    fi
  done
}

apply_settings "$SCHEMA_MAIN" SETTINGS_MAIN "Configurações Gerais"
apply_settings "$SCHEMA_KEYS" SETTINGS_KEYS "Atalhos de Teclado"

rm -f /tmp/forge-err.log

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo "Todas as configurações do Forge foram aplicadas com sucesso."
else
  echo "Algumas configurações falharam. Se o erro for 'No such schema', rode com SCHEMADIR apontando para o schema local da extensão."
  exit 1
fi
