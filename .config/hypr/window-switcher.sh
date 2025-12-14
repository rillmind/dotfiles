#!/bin/sh

# Lista clientes -> formata -> passa pro wofi -> foca na janela escolhida
hyprctl clients | grep "title:" | awk -F': ' '{print $2}' | \
wofi --dmenu --prompt "Janelas" | \
xargs -I{} hyprctl dispatch focuswindow "title:{}"
