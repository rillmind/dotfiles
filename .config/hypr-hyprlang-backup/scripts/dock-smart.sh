#!/bin/bash

DOCK_PID=""

start_dock() {
  nwg-dock-hyprland -d -i 36 -p bottom -l top -hd 0 -s /home/raul/.config/nwg-dock-hyprland/style.css &
  DOCK_PID=$!
}

stop_dock() {
  if [ -n "$DOCK_PID" ]; then
    kill "$DOCK_PID" 2>/dev/null
    DOCK_PID=""
  fi
}

handle() {
  case "$1" in
    openwindow*|closewindow*|activewindowv2*|workspacev2*)
      sleep 0.1
      current_ws=$(hyprctl activeworkspace -j | jq '.id')
      windows=$(hyprctl clients -j | jq '[.[] | select(.workspace.id == '$current_ws')] | length')
      if [ "$windows" -eq 0 ]; then
        [ -z "$DOCK_PID" ] && start_dock
      else
        [ -n "$DOCK_PID" ] && stop_dock
      fi
      ;;
  esac
}

start_dock
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
  handle "$line"
done
