#!/bin/bash

class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')
title=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // empty')

declare -A icons=(
  ["firefox"]="󰈹"
  ["kitty"]=""
  ["Alacritty"]=""
  ["code"]="󰨞"
  ["discord"]="󰙯"
  ["thunar"]="󰉋"
  ["spotify"]=""
  ["telegram-desktop"]=""
  ["obsidian"]="󰠮"
  ["app.zen_browser.zen"]="zen"
  ["com.mitchellh.ghostty"]="Ghotty"
)

icon="${icons[$class]:-}"
title="${title:0:40}"

echo "$icon $title"
