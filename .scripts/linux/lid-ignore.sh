#!/usr/bin/env bash
# Faz o systemd ignorar a tampa do notebook, para que fechá-la não suspenda o sistema.
# Só é preciso rodar de novo depois de reinstalar o sistema, porque o arquivo fica em /etc.
# Quem apaga e acende a tela é o Hyprland (seção "Tampa do notebook" em hyprland.lua).
#
# Uso:      ~/.scripts/linux/lid-ignore.sh   (pede a senha do sudo)
# Desfazer: sudo rm /etc/systemd/logind.conf.d/10-lid-ignore.conf
#           sudo systemctl reload systemd-logind
set -euo pipefail

sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-lid-ignore.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
CONF
sudo systemctl reload systemd-logind
