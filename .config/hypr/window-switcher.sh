#!/bin/sh

# Lista janelas -> passa pro wofi -> foca na janela escolhida (pelo endereço)
hyprctl clients -j | jq -r '.[] | select(.title != "") | "\(.address)\t\(.title)"' | \
wofi --dmenu --prompt "Janelas" | cut -f1 | \
xargs -r -I{} hyprctl dispatch 'hl.dsp.focus({ window = "address:{}" })'
