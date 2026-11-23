#!/usr/bin/env bash
# instalar.sh – setup mínimo do Hyprland (tema Vinho) num Fedora recém-instalado, com o Hyprland já
# instalado. Pode rodar de novo sem problema.
#
#   git clone https://github.com/rillmind/dotfiles ~/dotfiles && ~/dotfiles/.config/vinho/instalar.sh
#
#   --sem-pacotes   não instala nada, só liga as configs
#   --forcar        troca a config do Hyprland mesmo se ela já for a do dotfiles (setup completo)
set -eu
AQUI="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CFG="$HOME/.config"
pacotes=1; forcar=0
for a in "$@"; do
    case "$a" in
        --sem-pacotes) pacotes=0 ;;
        --forcar) forcar=1 ;;
        *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
    esac
done

# no setup completo não há o que instalar: o tema já entra no Super+Shift+T
if [ "$forcar" = 0 ] && [ -d "$CFG/quickshell" ] && [ "$(readlink -f "$CFG/hypr")" = "$(dirname "$AQUI")/hypr" ]; then
    echo "Este PC já usa o setup completo do dotfiles; nada foi alterado (use --forcar para trocar)."
    exit 0
fi

if [ "$pacotes" = 1 ]; then
    sudo dnf install -y waybar fuzzel dunst swaylock grim slurp wl-clipboard brightnessctl wireplumber jetbrains-mono-fonts
    if ! command -v ghostty >/dev/null; then
        sudo dnf install -y 'dnf-command(copr)' || true
        sudo dnf copr enable -y scottames/ghostty
        sudo dnf install -y ghostty
    fi
fi

mkdir -p "$CFG"
ligar() {    # destino origem: guarda o que existir e cria o link
    local destino="$1" origem="$2"
    [ "$(readlink -f "$destino")" = "$(readlink -f "$origem")" ] && return 0
    if [ -e "$destino" ] || [ -L "$destino" ]; then
        local b="$destino.antes-do-vinho.$(date +%Y%m%d-%H%M%S)"
        mv "$destino" "$b"; echo "backup: $b"
    fi
    ln -s "$origem" "$destino"
}
ligar "$CFG/vinho" "$AQUI"

# ~/.config/hypr pode ser um link para o setup completo: nunca escrever dentro dele
if [ -L "$CFG/hypr" ]; then
    mv "$CFG/hypr" "$CFG/hypr.antes-do-vinho.$(date +%Y%m%d-%H%M%S)"
fi
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
    mv "$CFG/hypr/hyprland.$outro" "$CFG/hypr/hyprland.$outro.antes-do-vinho.$(date +%Y%m%d-%H%M%S)"
fi
ligar "$CFG/hypr/hyprland.$usar" "$CFG/vinho/hyprland.$usar"
echo "Hyprland $versao: usando hyprland.$usar"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null && "$CFG/vinho/vinho.sh" iniciar
    echo "Pronto, já está valendo."
else
    echo "Pronto: é só entrar no Hyprland."
fi
echo "Alt+Espaço: apps · Alt+Enter: terminal · Alt+B: energia · Super+U: bloquear"
