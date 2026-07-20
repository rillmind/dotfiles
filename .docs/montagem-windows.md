# Montagem da Partição Windows

## 1. Identificar a partição

Usei `lsblk -f` para listar todas as partições do sistema.

A partição Windows é a **`/dev/nvme0n1p2`**, com formato **NTFS** (UUID `F6EA7C96EA7C54B9`).

## 2. Montar no local correto

O explorador de arquivos do GNOME/KDE só exibe montagens em `/run/media/$USER/`. Montei inicialmente em `/mnt/windows` (não aparecia no explorador), depois corrigi:

```bash
sudo umount /mnt/windows
sudo mkdir -p /run/media/raul/Windows
sudo mount -t ntfs-3g /dev/nvme0n1p2 /run/media/raul/Windows
```

## 3. Resultado

A partição foi montada em `/run/media/raul/Windows` e agora aparece no explorador de arquivos ao lado de `Games` e `Games 2`.
