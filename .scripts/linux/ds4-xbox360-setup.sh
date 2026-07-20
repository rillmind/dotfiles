#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Script de configuração: DualShock 4 → Xbox 360 via InputPlumber
# Uso: sudo bash ds4-xbox360-setup.sh
# ============================================================

CONFIG_FILE="/etc/inputplumber/devices.d/60-ps4_gamepad.yaml"
HIDE_CONF="/etc/systemd/system/inputplumber.service.d/hide.conf"

echo "[1/5] Criando diretório para overrides..."
mkdir -p /etc/inputplumber/devices.d

echo "[2/5] Escrevendo configuração do composite device..."
cat > "$CONFIG_FILE" << 'YAML'
# yaml-language-server: $schema=https://raw.githubusercontent.com/ShadowBlip/InputPlumber/main/rootfs/usr/share/inputplumber/schema/composite_device_v1.json
version: 1
kind: CompositeDevice
name: Sony Interactive Entertainment Wireless Controller
maximum_sources: 4
matches: []
source_devices:
  - group: gamepad
    udev:
      attributes:
        - name: name
          value: "*Wireless Controller"
        - name: id/vendor
          value: "054c"
        - name: id/product
          value: "{09cc,05c4}"
      sys_name: "event*"
      subsystem: input
    capability_map_id: swap_west_north
    config:
      led:
        fixed_color:
          r: 255
          g: 0
          b: 40

  - group: gamepad
    blocked: true
    udev:
      attributes:
        - name: name
          value: "*Wireless Controller Motion Sensors"
        - name: id/vendor
          value: "054c"
        - name: id/product
          value: "{09cc,05c4}"
      sys_name: "event*"
      subsystem: input

  - group: gamepad
    blocked: true
    udev:
      attributes:
        - name: name
          value: "*Wireless Controller Touchpad"
        - name: id/vendor
          value: "054c"
        - name: id/product
          value: "{09cc,05c4}"
      sys_name: "event*"
      subsystem: input

  - group: gamepad
    blocked: true
    udev:
      attributes:
        - name: idVendor
          value: "054c"
        - name: idProduct
          value: "{09cc,05c4}"
      subsystem: hidraw

target_devices:
  - xb360
YAML

echo "[3/5] Configurando systemd drop-in para esconder devices originais..."
mkdir -p /etc/systemd/system/inputplumber.service.d
printf "[Service]\nEnvironment=HIDE_DEVICES_FROM_ROOT=1\n" > "$HIDE_CONF"
systemctl daemon-reload

echo "[4/5] Reiniciando serviço do InputPlumber..."
systemctl restart inputplumber

echo "[5/5] Ativando gerenciamento de todos os devices..."
sleep 2
inputplumber devices manage-all --enable

echo ""
echo "Configuração concluída!"
echo "Conecte o DualShock 4 via Bluetooth. O LED deve acender vermelho rosado."
echo "Verifique com: cat /proc/bus/input/devices | grep -E 'Name=|Handlers=' | paste - - | grep -i xbox"
