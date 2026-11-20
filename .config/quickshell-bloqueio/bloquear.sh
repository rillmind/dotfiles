#!/usr/bin/env bash
# bloquear.sh – trava a tela com a tela de bloqueio do quickshell (shell.qml desta pasta).
# Só deixa uma rodando; volta assim que a tela travou (para o before-sleep do swayidle).
# Se o quickshell cair com a tela travada, sobe de novo na hora (o Hyprland deixa com
# misc.allow_session_lock_restore); depois de 5 crashes, troca pelo swaylock para não ficar exposto.
DIR="$(dirname "$(readlink -f "$0")")"
RUN="${XDG_RUNTIME_DIR:-/run/user/$UID}"
MARCA="$RUN/quickshell-bloqueio.ativo"

# laço que segura a tela (roda em sessão própria para não morrer junto com quem chamou)
if [ "${1:-}" = "--laco" ]; then
    crashes=0
    while :; do
        quickshell -p "$DIR"; rc=$?
        case $rc in 134|135|139) ;; *) break ;; esac
        crashes=$((crashes + 1))
        [ $crashes -gt 5 ] && { swaylock; break; }
    done
    rm -f "$MARCA"
    exit 0
fi

exec 9>"$RUN/quickshell-bloqueio.lock"
flock -n 9 || exit 0              # já está travada (o laço herda e segura o flock)
rm -f "$MARCA"
setsid -f "$0" --laco >/dev/null 2>&1 </dev/null

for _ in $(seq 30); do [ -e "$MARCA" ] && exit 0; sleep 0.1; done
