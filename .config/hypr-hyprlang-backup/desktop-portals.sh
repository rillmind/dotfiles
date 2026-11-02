#!/bin/bash
killall xdg-desktop-portal-hyprland xdg-desktop-portal xdg-desktop-portal-gtk 2>/dev/null
sleep 1

/usr/libexec/xdg-desktop-portal-hyprland &
sleep 1
/usr/libexec/xdg-desktop-portal &
sleep 1
/usr/libexec/xdg-desktop-portal-gtk &

