#!/usr/bin/env bash
#
# popshell-shortcuts.sh
#
# Reaplica a configuração do Pop Shell definida abaixo.
# Edite os valores dentro de SETTINGS e rode o script sempre que quiser
# reimpor esse estado (ex: depois de uma atualização da extensão, reset,
# ou em uma nova máquina).
#
# Uso:
#   ./popshell-shortcuts.sh
#
# Se a extensão foi instalada via `make local-install` (build do source),
# defina a variável SCHEMADIR antes de rodar, ou exporte-a no seu shell:
#   SCHEMADIR=~/.local/share/gnome-shell/extensions/pop-shell@system76.com/schemas ./popshell-shortcuts.sh

set -euo pipefail

SCHEMA="org.gnome.shell.extensions.pop-shell"
SCHEMADIR="${SCHEMADIR:-}"

# ---------------------------------------------------------------------------
# EDITE AQUI: chave = valor (no formato que o gsettings espera)
#   - arrays de atalhos:      "['<Alt>Down', '<Alt>j']"
#   - arrays vazios (as):     "@as []"
#   - strings:                "'rgb(203,166,247)'"   (aspas simples fazem parte do valor)
#   - booleanos:               true / false
#   - números (uint32/int):    8 / 0 / 64
# ---------------------------------------------------------------------------
declare -A SETTINGS=(
  [activate-launcher]="['<Alt>slash']"
  [active-hint]="true"
  [active-hint-border-radius]="8"
  [column-size]="64"
  [focus-down]="['<Alt>Down', '<Alt>KP_Down', '<Alt>j']"
  [focus-left]="['<Alt>Left', '<Alt>KP_Left', '<Alt>h']"
  [focus-right]="['<Alt>Right', '<Alt>KP_Right', '<Alt>l']"
  [focus-up]="['<Alt>Up', '<Alt>KP_Up', '<Alt>k']"
  [fullscreen-launcher]="false"
  [gap-inner]="2"
  [gap-outer]="2"
  [hint-color-rgba]="'rgb(203,166,247)'"
  [log-level]="0"
  [management-orientation]="['o']"
  [max-window-width]="0"
  [mouse-cursor-focus-location]="4"
  [mouse-cursor-follows-active-window]="true"
  [pop-monitor-down]="['<Alt><Shift><Primary>KP_Down']"
  [pop-monitor-left]="['<Alt><Shift>KP_Left']"
  [pop-monitor-right]="'<Alt><Shift>KP_Right']"
  [pop-monitor-up]="[''<Alt><Shift><Primary>KP_Up']"
  [pop-workspace-down]="['<Alt><Shift>Down', '<Alt><Shift>KP_Down']"
  [pop-workspace-up]="['<Alt><Shift>Up', '<Alt><Shift>KP_Up']"
  [row-size]="64"
  [show-skip-taskbar]="true"
  [show-title]="false"
  [smart-gaps]="false"
  [snap-to-grid]="false"
  [stacking-with-mouse]="true"
  [tile-accept]="['Return', 'KP_Enter']"
  [tile-by-default]="true"
  [tile-enter]="['<Super>Return']"
  [tile-move-down]="['Down', 'KP_Down', 'j']"
  [tile-move-down-global]="@as []"
  [tile-move-left]="['Left', 'KP_Left', 'h']"
  [tile-move-left-global]="@as []"
  [tile-move-right]="['Right', 'KP_Right', 'l']"
  [tile-move-right-global]="@as []"
  [tile-move-up]="['Up', 'KP_Up', 'k']"
  [tile-move-up-global]="@as []"
  [tile-orientation]="['<Alt>o']"
  [tile-reject]="['Escape']"
  [tile-resize-down]="['<Shift>Down', '<Shift>KP_Down', '<Shift>j']"
  [tile-resize-left]="['<Shift>Left', '<Shift>KP_Left', '<Shift>h']"
  [tile-resize-right]="['<Shift>Right', '<Shift>KP_Right', '<Shift>l']"
  [tile-resize-up]="['<Shift>Up', '<Shift>KP_Up', '<Shift>k']"
  [tile-swap-down]="['<Primary>Down', '<Primary>KP_Down', '<Alt><Shift>j']"
  [tile-swap-left]="['<Primary>Left', '<Primary>KP_Left']"
  [tile-swap-right]="['<Primary>Right', '<Primary>KP_Right']"
  [tile-swap-up]="['<Primary>Up', '<Primary>KP_Up', '<Alt><Shift>k']"
  [toggle-floating]="['<Alt>g']"
  [toggle-stacking]="['s']"
)
# ---------------------------------------------------------------------------

GSETTINGS=(gsettings)
if [[ -n "$SCHEMADIR" ]]; then
  GSETTINGS=(gsettings --schemadir "$SCHEMADIR")
fi

echo "Aplicando configuração do Pop Shell (schema: $SCHEMA)..."

fail=0
for key in "${!SETTINGS[@]}"; do
  value="${SETTINGS[$key]}"
  if "${GSETTINGS[@]}" set "$SCHEMA" "$key" "$value" 2>/tmp/popshell-err.log; then
    printf '  ✔ %-32s %s\n' "$key" "$value"
  else
    printf '  ✘ %-32s FALHOU (%s)\n' "$key" "$(cat /tmp/popshell-err.log)"
    fail=1
  fi
done

rm -f /tmp/popshell-err.log

if [[ "$fail" -eq 0 ]]; then
  echo "Todos os atalhos foram aplicados com sucesso."
else
  echo "Alguns atalhos falharam. Se o erro for 'No such schema', rode com SCHEMADIR apontando para o schema local da extensão."
  exit 1
fi
