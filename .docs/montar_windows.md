# Montar partição Windows no Fedora

## Método 1 — Automático (gerenciador de arquivos)

Abra o *Arquivos* (Nautilus), clique na partição NTFS na barra lateral. Ela monta automaticamente em `/run/media/raul/`.

## Método 2 — Terminal (montagem manual)

```bash
# 1. Criar o ponto de montagem (só precisa uma vez)
sudo mkdir -p /run/media/raul/Windows

# 2. Montar a partição
sudo mount -t ntfs-3g /dev/nvme0n1p2 /run/media/raul/Windows
```

## Método 3 — Montagem automática no boot (opcional)

Edite o `/etc/fstab` para montar sempre que ligar o PC:

```bash
sudo nano /etc/fstab
```

Adicione esta linha no final:

```
/dev/nvme0n1p2  /run/media/raul/Windows  ntfs-3g  defaults,uid=1000,gid=1000  0  0
```

Salve (`Ctrl+O`, `Enter`, `Ctrl+X`). A partir do próximo reboot a partição já estará montada.
