#!/bin/sh

# xset s off dpms 0 0 0

# xset s on dpms 1800 0 0

i3lock \
  -i ~/Imagens/wallpapers/arch-black-1080p.png \
  --inside-color=1e1e2ecc \
  --ring-color=89b4fac0 \
  --line-color=1e1e2e00 \
  --keyhl-color=a6e3a1cc \
  --bshl-color=f38ba8cc \
  --separator-color=1e1e2e00 \
  --ring-width=6 \
  --radius=130 \
  --time-font="JetBrainsMono Nerd Font" \
  --date-font="JetBrainsMono Nerd Font" \
  --time-size=32 \
  --date-size=18 \
  --time-color=cdd6f4ff \
  --date-color=a6adc8ff \
  --time-str="%H:%M" \
  --date-str="%A, %d %B"
