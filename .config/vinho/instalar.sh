#!/usr/bin/env bash
# instalar.sh – leva o desktop do dotfiles para um Fedora recém-instalado, com o Hyprland já instalado.
# Pode rodar de novo sem problema; o que existir no lugar vira backup (*.antes-do-vinho.*).
#
#   git clone https://github.com/rillmind/dotfiles ~/dotfiles && ~/dotfiles/.config/vinho/instalar.sh
#
#   (sem opções)    etapa 1: Hyprland mínimo + tema Vinho do quickshell. Já dá para usar o PC.
#   --completo      etapa 2, quando o resto estiver instalado: config completa do Hyprland, os 3 temas
#                   (Super+Shift+T) e os apps que seguem o tema. Mostra o que ainda falta instalar.
#   --sem-pacotes   não instala nada, só liga as configs
#   --forcar        volta para a etapa 1 num PC que já está na completa
set -eu
AQUI="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(cd "$AQUI/../.." && pwd)"
CFG="$HOME/.config"
pacotes=1; forcar=0; completo=0
for a in "$@"; do
    case "$a" in
        --sem-pacotes) pacotes=0 ;;
        --forcar) forcar=1 ;;
        --completo) completo=1 ;;
        *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    esac
done
AGORA="$(date +%Y%m%d-%H%M%S)"
ligar() {    # destino origem: guarda o que existir e cria o link
    local destino="$1" origem="$2"
    [ -e "$origem" ] || return 0
    [ "$(readlink -f "$destino")" = "$(readlink -f "$origem")" ] && return 0
    if [ -e "$destino" ] || [ -L "$destino" ]; then
        mv "$destino" "$destino.antes-do-vinho.$AGORA"; echo "backup: $destino.antes-do-vinho.$AGORA"
    fi
    mkdir -p "$(dirname "$destino")"
    ln -s "$origem" "$destino"
}
recarregar() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null || true
        "$CFG/quickshell/tema.sh" iniciar
        echo "Pronto, já está valendo."
    else
        echo "Pronto: é só entrar no Hyprland."
    fi
}
base() {    # o que as duas etapas usam
    ligar "$CFG/vinho" "$AQUI"
    for d in quickshell quickshell-bloqueio quickshell-apps; do ligar "$CFG/$d" "$REPO/.config/$d"; done
    ligar "$HOME/.fonts" "$REPO/.fonts"      # JetBrainsMono Nerd Font (ícones dos painéis)
    command -v fc-cache >/dev/null && fc-cache >/dev/null 2>&1 || true
}

if [ "$completo" = 1 ]; then
    base
    # o Catppuccin e o Gruvbox usam o jq; o swaybg põe os papéis de parede
    [ "$pacotes" = 0 ] || sudo dnf install -y jq swaybg
    for d in hypr ghostty tmux nvim gtk-4.0 yazi zathura btop swaylock wofi; do ligar "$CFG/$d" "$REPO/.config/$d"; done
    ligar "$HOME/.tmux.conf" "$REPO/.tmux.conf"
    ligar "$HOME/.scripts" "$REPO/.scripts"
    for f in "$REPO"/.config/tmux/fonte/*.ttf; do ligar "$HOME/.local/share/fonts/$(basename "$f")" "$f"; done
    # lembrete do que os temas e a config completa chamam
    falta=""
    for c in jq swaybg swayidle swaylock tmux nvim btop yazi zathura socat flatpak pactl zenity wofi udiskie gammastep ghostty; do
        command -v "$c" >/dev/null || falta="$falta $c"
    done
    [ -z "$falta" ] || echo "Ainda não instalados (o resto funciona sem eles):$falta"
    grep -q 'LIBVA_DRIVER_NAME", "nvidia"' "$REPO/.config/hypr/hyprland.lua" && [ ! -e /proc/driver/nvidia/version ] &&
        echo "Atenção: o hypr/hyprland.lua tem variáveis da NVIDIA e monitores do notebook; revise para esta máquina."
    recarregar
    exit 0
fi

if [ "$forcar" = 0 ] && [ "$(readlink -f "$CFG/hypr")" = "$(readlink -f "$REPO/.config/hypr")" ]; then
    echo "Este PC já usa a config completa; nada foi alterado (use --forcar para voltar à mínima)."
    exit 0
fi

if [ "$pacotes" = 1 ]; then
    sudo dnf install -y quickshell grim slurp wl-clipboard brightnessctl wireplumber upower procps-ng NetworkManager gawk
    if ! command -v ghostty >/dev/null; then
        sudo dnf install -y 'dnf-command(copr)' || true
        sudo dnf copr enable -y scottames/ghostty
        sudo dnf install -y ghostty
    fi
fi

mkdir -p "$CFG"
base
E="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
mkdir -p "$E/aparencia"
echo Vinho > "$E/tema-ativo"
echo vinho > "$E/aparencia/paleta"

# ~/.config/hypr pode ser um link para a config completa: nunca escrever dentro dele
if [ -L "$CFG/hypr" ]; then mv "$CFG/hypr" "$CFG/hypr.antes-do-vinho.$AGORA"; fi
mkdir -p "$CFG/hypr"

# Lua a partir do 0.57; antes disso, .conf. O outro formato sai do caminho, para não valer no lugar deste.
versao=$( { Hyprland --version || hyprland --version || hyprctl version; } 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
if [ -z "$versao" ]; then
    echo "Hyprland não encontrado: instale-o e rode de novo." >&2
    echo "  sudo dnf copr enable sdegler/hyprland && sudo dnf install hyprland" >&2
    exit 1
fi
if [ "$(printf '%s\n' 0.57 "$versao" | sort -V | head -1)" = 0.57 ]; then usar=lua; outro=conf; else usar=conf; outro=lua; fi
if [ -e "$CFG/hypr/hyprland.$outro" ] || [ -L "$CFG/hypr/hyprland.$outro" ]; then
    mv "$CFG/hypr/hyprland.$outro" "$CFG/hypr/hyprland.$outro.antes-do-vinho.$AGORA"
fi
ligar "$CFG/hypr/hyprland.$usar" "$CFG/vinho/hyprland.$usar"
echo "Hyprland $versao: usando hyprland.$usar"
recarregar
echo "Alt+Espaço: apps · Alt+Enter: terminal · Alt+B: energia · Super+U: bloquear"
echo "Quando o resto estiver instalado: $AQUI/instalar.sh --completo"
