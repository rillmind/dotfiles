#!/bin/zsh

zen() {
  hyprctl dispatch exec '[workspace 1] flatpak run app.zen_browser.zen'
}

thunderbird() {
  hyprctl dispatch exec '[workspace 1] flatpak run org.mozilla.Thunderbird'
}

ghostty() {
  hyprctl dispatch exec '[workspace 2] ghostty'
}

spotify() {
  hyprctl dispatch exec "[workspace 3] flatpak run com.spotify.Client"
}

zen && thunderbird && ghostty && spotify
