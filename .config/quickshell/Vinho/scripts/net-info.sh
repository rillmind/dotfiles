#!/bin/sh
# Imprime o estado da rede numa linha: tipo|ssid|sinal|ip  (tipo = wifi | ethernet | disconnected)
export LANGUAGE=C LC_ALL=C

ip=$(ip -4 -o route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')
# no modo -t o nmcli escapa ":" dentro do SSID como "\:"
wifi=$(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi 2>/dev/null | sed 's/\\:/\x01/g' | awk -F: '$1 == "*" { print $2 "|" $3; exit }' | tr '\001' ':')

if [ -n "$wifi" ]; then
    echo "wifi|$wifi|$ip"
elif nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected'; then
    echo "ethernet|||$ip"
else
    echo "disconnected|||"
fi
