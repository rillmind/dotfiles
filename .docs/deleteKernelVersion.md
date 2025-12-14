# Deletar versão específica de kernel

## Arch

### Liste os kernels instalados

```sh
yay -Q | grep linux
```

Identifique a versão que deseja remover (não remova a que está em uso; verifique com uname -r).

### Remova o pacote

```sh
yay -Rns linux-lts
```

### Atualize grub

```sh
yay -Rns linux-lts
```

## Fedora

### Liste os kernels instalados

```sh
rpm -qa kernel-core
```

Identifique a versão que deseja remover (não remova a que está em uso; verifique com uname -r).

### Remova o pacote

```sh
sudo dnf remove kernel-core-VERSAO
```

### Alternativa (remove todos exceto os 2 mais recentes)

```sh
sudo dnf remove --oldinstallonly --setopt installonly_limit=2
```
