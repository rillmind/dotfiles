#!/usr/bin/env bash
# nvibrant-hdmi.sh – aplica a vibrância na TV no login e de novo sempre que um monitor HDMI é conectado.
# O nvibrant recebe um valor por saída da placa NVIDIA, em ordem; a primeira é o HDMI.
VIBRANCIA=700
aplicar() { "$HOME/.local/bin/nvibrant" "$VIBRANCIA" >/dev/null 2>&1; }

aplicar
sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r ev; do
    case "$ev" in
        monitoradded\>\>HDMI*) sleep 1; aplicar ;;   # espera o modo da TV assentar
    esac
done
