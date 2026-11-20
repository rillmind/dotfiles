#!/usr/bin/env bash
# aparencia.sh – leva o tema do quickshell para o resto do sistema: bordas do Hyprland, Ghostty,
# Neovim, tmux, btop, zathura, yazi, swaylock, wofi, Obsidian, apps GTK4 (cores e claro/escuro) e papel de parede.
#
# Paletas: catppuccin-mocha (tema Catppuccin-mocha), gruvbox-escuro e gruvbox-claro (tema Gruvbox).
# As configs dos apps apontam para links "tema-ativo" que levam a ~/.local/state/quickshell/aparencia;
# só esses arquivos de estado mudam numa troca, o repositório de dotfiles fica igual.
#
#   aparencia.sh aplicar [paleta]   aplica a paleta do tema ativo (ou a indicada) e recarrega os apps abertos
#   aparencia.sh wallpaper          escolhe o papel de parede da paleta atual (fica salvo)
#   aparencia.sh paleta             mostra a paleta atual
set -u

QS="$HOME/.config/quickshell"
CFG="$HOME/.config"
ST="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
AP="$ST/aparencia"
WALL_PADRAO="$HOME/Nextcloud/Imagens/Wallpapers/blobs-d.png"
OBSIDIAN_VAULT="$HOME/Documentos/Obsidian"
mkdir -p "$AP"

paleta_atual() {
    case "$("$QS/tema.sh" ativo)" in
        Gruvbox) [ "$(cat "$ST/gruvbox-modo" 2>/dev/null)" = claro ] && echo gruvbox-claro || echo gruvbox-escuro ;;
        *) echo catppuccin-mocha ;;
    esac
}

# papel de parede salvo da paleta; o Gruvbox claro usa o do escuro até ter um próprio
wallpaper_de() {
    local k f
    for k in "$1" $([ "$1" = gruvbox-claro ] && echo gruvbox-escuro); do
        f=$(cat "$AP/wallpaper-$k" 2>/dev/null)
        [ -f "$f" ] && { echo "$f"; return; }
    done
    echo "$WALL_PADRAO"
}
aplicar_wallpaper() {
    local img="$1"
    # não reinicia o swaybg à toa (evita piscar quando só o resto do tema muda)
    if [ "$(cat "$AP/wallpaper-atual" 2>/dev/null)" = "$img" ] && pgrep -x swaybg >/dev/null; then return; fi
    pkill -x swaybg
    setsid -f swaybg -i "$img" -m fill >/dev/null 2>&1 </dev/null
    echo "$img" > "$AP/wallpaper-atual"
}

# Obsidian: tema, claro/escuro e cor de destaque do vault principal (o resto do appearance.json fica igual).
# Reescreve no mesmo arquivo (sem mv) para o Obsidian aberto perceber a mudança.
aplicar_obsidian() {
    local f="$OBSIDIAN_VAULT/.obsidian/appearance.json" novo
    [ -f "$f" ] || return 0
    novo=$(jq --arg t "$1" --arg m "$2" --arg a "$3" '.cssTheme = $t | .theme = $m | .accentColor = $a' "$f") || return 0
    [ "$novo" = "$(cat "$f")" ] || printf '%s\n' "$novo" > "$f"
}

aplicar() {
    local p="${1:-$(paleta_atual)}" escuro=1 ghostty zathura btop
    case "$p" in
        catppuccin-mocha) ghostty="catppuccin-mocha.conf"; zathura="catppuccin-mocha"; btop="$CFG/btop/themes/catppuccin_mocha.theme" ;;
        gruvbox-escuro)   ghostty="Gruvbox Dark";          zathura="gruvbox-dark";     btop="/usr/share/btop/themes/gruvbox_dark.theme" ;;
        gruvbox-claro)    ghostty="Gruvbox Light";         zathura="gruvbox-light";    btop="/usr/share/btop/themes/gruvbox_light.theme"; escuro=0 ;;
        *) echo "paleta desconhecida: $p" >&2; return 1 ;;
    esac

    # ── estado (os links tema-ativo dos apps apontam para cá) ──
    echo "$p" > "$AP/paleta"
    echo "theme = $ghostty" > "$AP/ghostty"
    ln -sfn "$CFG/zathura/$zathura" "$AP/zathura"
    ln -sfn "$btop" "$AP/btop.theme"
    ln -sfn "$CFG/yazi/temas/$p.toml" "$AP/yazi.toml"
    ln -sfn "$CFG/swaylock/$p" "$AP/swaylock"
    ln -sfn "$CFG/wofi/colors/$p.css" "$AP/wofi.css"
    ln -sfn "$CFG/tmux/temas/$p.conf" "$AP/tmux.conf"
    # GTK4: link relativo dentro da pasta, para os flatpaks (que só enxergam ~/.config/gtk-4.0) seguirem
    ln -sfn "temas/$p.css" "$CFG/gtk-4.0/gtk.css"

    # ── recarrega o que está aberto ──
    hyprctl reload >/dev/null 2>&1                         # bordas (hypr/paleta.lua lê o arquivo paleta)
    pkill -USR2 -x ghostty                                 # Ghostty relê a config
    pkill -USR2 -x btop                                    # btop relê a config e o tema
    for z in $(busctl --user list --no-legend 2>/dev/null | awk '$1 ~ /^org\.pwmt\.zathura\.PID/ {print $1}'); do
        gdbus call --session --dest "$z" --object-path /org/pwmt/zathura --method org.pwmt.zathura.SourceConfig >/dev/null 2>&1
    done
    for s in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*.0; do    # cada nvim aberto (lua/tema.lua)
        [ -S "$s" ] && timeout 2 nvim --server "$s" --remote-expr 'luaeval("require(\"tema\").aplicar()")' >/dev/null 2>&1
    done
    # tmux: o plugin catppuccin "congela" cores no primeiro carregamento (opções set -o), então
    # limpa as opções dele e relê só o visual (~/.config/tmux/visual.conf)
    if tmux info >/dev/null 2>&1; then
        for o in $( { tmux show-options -g; tmux show-options -gw; } | awk '$1 ~ /^@(catppuccin|_ctp|thm)_/ {print $1}' | sort -u); do
            tmux set -gu "$o" 2>/dev/null; tmux set -gwu "$o" 2>/dev/null
        done
        tmux source-file "$CFG/tmux/visual.conf"
    fi
    case "$p" in   # tema · modo (obsidian = escuro, moonstone = claro) · destaque
        catppuccin-mocha) aplicar_obsidian "Catppuccin" obsidian "#cba6f7" ;;
        gruvbox-escuro)   aplicar_obsidian "Obsidian gruvbox" obsidian "#fe8019" ;;
        gruvbox-claro)    aplicar_obsidian "Obsidian gruvbox" moonstone "#af3a03" ;;
    esac
    # apps GTK4/libadwaita (Nautilus, Mission Center): cores do gtk.css acima + claro/escuro; o Zen segue o color-scheme
    gsettings set org.gnome.desktop.interface color-scheme "$([ $escuro = 1 ] && echo prefer-dark || echo prefer-light)"
    aplicar_wallpaper "$(wallpaper_de "$p")"
    # yazi, swaylock e wofi leem o tema ao abrir
}

escolher_wallpaper() {
    local p f atual
    p=$(paleta_atual)
    atual=$(wallpaper_de "$p")
    # GDK_DEBUG=portals: usa o seletor de arquivos do portal (o mesmo dos outros apps)
    f=$(GDK_DEBUG=portals zenity --file-selection --title="Papel de parede · $p" --filename="$(dirname "$atual")/" \
        --file-filter='Imagens | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP' 2>/dev/null) || return 0
    [ -f "$f" ] || return 0
    echo "$f" > "$AP/wallpaper-$p"
    aplicar_wallpaper "$f"
}

case "${1:-}" in
    aplicar) aplicar "${2:-}" ;;
    wallpaper) escolher_wallpaper ;;
    paleta) paleta_atual ;;
    *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
