#!/usr/bin/env bash

# Retorna o SSID da rede Wi-Fi ativa
LANGUAGE=C nmcli -t -f active,ssid dev wifi | awk -F: '$1 ~ /^yes/ {print $2}'
