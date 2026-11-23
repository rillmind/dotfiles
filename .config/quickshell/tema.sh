#!/usr/bin/env bash
# tema.sh – inicia e troca os temas do quickshell. Cada pasta ao lado deste script com um shell.qml
# é um tema (config completa e independente); o tema escolhido fica salvo e volta no próximo login.
# Ao iniciar e ao trocar, o aparencia.sh leva o tema para os outros apps (Hyprland, Ghostty, nvim…).
#
# O tema Vinho é a exceção: não usa quickshell (waybar + fuzzel + dunst, em ~/.config/vinho).
#
#   tema.sh iniciar           inicia o tema salvo (exec-once do Hyprland)
#   tema.sh trocar [nome]     troca para <nome>, ou para o próximo tema da lista
#   tema.sh ipc <alvo> <fn>   chama um IpcHandler do tema em execução (ex: ipc launcher toggle)
#   tema.sh ativo | lista     mostra o tema salvo | os temas disponíveis
set -u

DIR="$HOME/.config/quickshell"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/tema-ativo"

VINHO="$HOME/.config/vinho/vinho.sh"
lista() { for f in "$DIR"/*/shell.qml; do basename "$(dirname "$f")"; done; [ -x "$VINHO" ] && echo Vinho; }
existe() { lista | grep -qxF -- "$1"; }
ativo() {
    local t
    t=$(cat "$STATE" 2>/dev/null)
    if [ -n "$t" ] && existe "$t"; then echo "$t"; else lista | head -1; fi
}
# só as instâncias de tema (a tela de bloqueio, em ~/.config/quickshell-bloqueio, fica de fora)
parar() {
    [ -x "$VINHO" ] && "$VINHO" parar
    pkill -f "^quickshell -p $DIR/"
    for _ in $(seq 40); do pgrep -f "^quickshell -p $DIR/" >/dev/null || return 0; sleep 0.05; done
    pkill -9 -f "^quickshell -p $DIR/"
}
# sobe o tema e o reinicia se ele cair com crash (SIGSEGV/SIGABRT/SIGBUS = saída 139/134/135);
# saída normal ou pkill (SIGTERM, 143) encerram o laço. Mais de 5 crashes em 1 min: desiste.
subir() {
    if [ "$1" = Vinho ]; then "$VINHO" iniciar; return; fi
    setsid -f bash -c '
        crashes=0; inicio=$(date +%s)
        while :; do
            quickshell -p "$1"; rc=$?
            case $rc in 134|135|139) ;; *) exit 0 ;; esac
            agora=$(date +%s)
            [ $((agora - inicio)) -gt 60 ] && { crashes=0; inicio=$agora; }
            crashes=$((crashes + 1)); [ $crashes -gt 5 ] && exit 1
            sleep 1
        done' _ "$DIR/$1" >/dev/null 2>&1 </dev/null
}

case "${1:-}" in
    iniciar)
        parar
        "$DIR/aparencia.sh" aplicar
        subir "$(ativo)"
        ;;
    trocar)
        alvo="${2:-}"
        if [ -z "$alvo" ]; then
            atual=$(ativo)
            alvo=$(lista | awk -v a="$atual" 'NR==1{p=$0} f{print; f=0; d=1} $0==a{f=1} END{if(!d) print p}' | head -1)
        fi
        existe "$alvo" || { echo "tema desconhecido: $alvo (temas: $(lista | tr '\n' ' '))" >&2; exit 1; }
        mkdir -p "$(dirname "$STATE")"
        echo "$alvo" > "$STATE"
        parar
        "$DIR/aparencia.sh" aplicar
        subir "$alvo"
        ;;
    ipc)
        shift
        if [ "$(ativo)" = Vinho ]; then
            case "$*" in
                "launcher toggle") exec "$VINHO" launcher ;;
                "launcher power") exec "$VINHO" energia ;;
                *) exit 0 ;;    # o resto só existe nos temas do quickshell
            esac
        fi
        exec quickshell -p "$DIR/$(ativo)" ipc call "$@"
        ;;
    ativo) ativo ;;
    lista) lista ;;
    *)
        sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
