#!/usr/bin/env bash
# Prepara o Fedora para jogar: Steam e Lutris nativos (sem flatpak, para a Steam conseguir abrir jogos
# do Lutris), ProtonUp-Qt e a partição do Windows montada sozinha em /mnt/windows, onde ficam os jogos.
# Uso: sudo ~/.scripts/linux/setup-jogos.sh
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo $0"; exit 1; }
USER_NAME="${SUDO_USER:-raul}"
USER_ID="$(id -u "$USER_NAME")"
GROUP_ID="$(id -g "$USER_NAME")"

WIN_UUID="F6EA7C96EA7C54B9"
MOUNT_POINT="/mnt/windows"
# opções recomendadas pelo Proton para discos NTFS; nofail: o boot não trava se a partição faltar
FSTAB_LINE="UUID=$WIN_UUID $MOUNT_POINT ntfs-3g uid=$USER_ID,gid=$GROUP_ID,rw,user,exec,umask=000,nofail 0 0"

echo "==> Instalando Steam e Lutris"
# o Lutris trava ao abrir sem o xrandr; o vulkan-tools ele usa para checar o Vulkan
dnf install -y steam lutris xrandr vulkan-tools

echo "==> Instalando ProtonUp-Qt (flatpak)"
flatpak install -y --or-update flathub net.davidotek.pupgui2

echo "==> Montagem automática da partição do Windows em $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"
if grep -q "$WIN_UUID" /etc/fstab; then
    echo "    /etc/fstab já tem a partição, não mexi"
else
    cp /etc/fstab "/etc/fstab.antes-setup-jogos"
    printf '\n# Partição do Windows, onde ficam os jogos (setup-jogos.sh)\n%s\n' "$FSTAB_LINE" >> /etc/fstab
    systemctl daemon-reload
    echo "    linha adicionada; cópia anterior em /etc/fstab.antes-setup-jogos"
fi
# desmonta a montagem feita pelo gerenciador de arquivos, se houver, e monta pelo fstab
umount /dev/disk/by-uuid/"$WIN_UUID" 2>/dev/null || true
mount "$MOUNT_POINT"
findmnt "$MOUNT_POINT"

echo "==> Pronto"
