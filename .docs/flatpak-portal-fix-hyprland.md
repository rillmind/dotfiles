# Relatório: File Chooser de Apps Flatpak Não Abre no Hyprland

## Data
14/07/2026

## Problema
Apps Flatpak (Gear Lever, Firefox, GIMP, etc.) não conseguem abrir o explorador de arquivos (file chooser). O diálogo "Abrir arquivo" simplesmente não aparece ou falha silenciosamente.

## Causa Raiz
O problema **não é específico de nenhum app** — afeta **todos os aplicativos Flatpak** que usam o portal de arquivos (`org.freedesktop.portal.FileChooser`). A causa é que o serviço principal do portal (`xdg-desktop-portal`) e seu backend Hyprland (`xdg-desktop-portal-hyprland`) **não estão rodando** porque o `graphical-session.target` do systemd nunca é ativado no Hyprland.

### Cadeia de Dependências (systemd user units)

```
graphical-session.target (INACTIVE — Hyprland não ativa)
  ├── xdg-desktop-portal.service         (Requisite=graphical-session.target) → NÃO SOBE
  ├── xdg-desktop-portal-hyprland.service (PartOf=graphical-session.target)   → NÃO SOBE
  └── xdg-desktop-portal-gtk.service      (sem essa dependência)             → FUNCIONA
```

- `graphical-session.target` é um target do systemd que **recusa** inicialização manual (`RefuseManualStart=yes`)
- Hyprland (ao contrário de GNOME/KDE) **não ativa** este target ao iniciar
- `xdg-desktop-portal.service` tem `Requisite=graphical-session.target`, o que impede sua ativação se o target não estiver ativo
- Sem `xdg-desktop-portal`, o nome D-Bus `org.freedesktop.portal.Desktop` (que expõe a interface `FileChooser`) **não é registrado**
- **Qualquer** app Flatpak que chama `org.freedesktop.portal.FileChooser` recebe **silêncio/erro** e o explorador não abre

### Diagnóstico

```bash
# Serviços do portal
$ systemctl --user status graphical-session.target
● graphical-session.target - Current graphical user session
     Active: inactive (dead)   ← PROBLEMA

$ systemctl --user status xdg-desktop-portal.service
○ xdg-desktop-portal.service - Portal service
     Active: inactive (dead)
     Dependency failed for xdg-desktop-portal.service   ← CONFIRMADO

# Nomes D-Bus registrados (ANTES da correção)
$ busctl list | grep portal
:1.109  flatpak-portal                     # org.freedesktop.portal.Flatpak
                                       # org.freedesktop.portal.Desktop  ← AUSENTE!
                                       # org.freedesktop.impl.portal.desktop.hyprland ← AUSENTE!

# Nomes D-Bus registrados (DEPOIS de iniciar manualmente)
$ busctl list | grep portal
org.freedesktop.impl.portal.desktop.gtk
org.freedesktop.impl.portal.desktop.hyprland   ← AGORA PRESENTE
org.freedesktop.portal.Desktop                  ← AGORA PRESENTE (inclui FileChooser)
org.freedesktop.portal.Documents
org.freedesktop.portal.Flatpak
```

## Solução Aplicada (válida para o sistema todo)

### 1. Script de inicialização dos portais (`~/.config/hypr/desktop-portals.sh`)

Criado/atualizado o script que sobre os portais manualmente na ausência do `graphical-session.target`:

```bash
#!/bin/bash
killall xdg-desktop-portal-hyprland xdg-desktop-portal xdg-desktop-portal-gtk 2>/dev/null
sleep 1

/usr/libexec/xdg-desktop-portal-hyprland &
sleep 1
/usr/libexec/xdg-desktop-portal &
sleep 1
/usr/libexec/xdg-desktop-portal-gtk &
```

### 2. Hyprland config (`~/.config/hypr/hyprland.conf`)

Adicionado `exec-once` para executar o script automaticamente ao iniciar a sessão Hyprland:

```conf
exec-once = ~/.config/hypr/desktop-portals.sh
```

Isso garante que os portais estejam disponíveis para **todos os apps Flatpak** durante toda a sessão.

## Por que não usar override do systemd?

`graphical-session.target` tem `RefuseManualStart=yes` e não pode ser iniciado manualmente. A abordagem mais limpa e confiável para Hyprland é iniciar os portais via `exec-once` no próprio hyprland.conf, que é o ponto de entrada garantido da sessão.

## Efeito Colateral

Nenhum. Os portais **já estavam rodando parcialmente** (`flatpak-portal`, `xdg-document-portal`, `xdg-desktop-portal-gtk` estavam ativos). Apenas o `xdg-desktop-portal` principal e o backend Hyprland que estavam faltando. A correção completa todos os serviços necessários para o sistema inteiro.

## Verificação

Para confirmar que está funcionando:

```bash
# Verificar se os portais estão rodando
busctl list | grep -iE "portal|file|chooser"
# Deve mostrar:
#   org.freedesktop.impl.portal.desktop.hyprland
#   org.freedesktop.impl.portal.desktop.gtk
#   org.freedesktop.portal.Desktop
#   org.freedesktop.portal.Documents
#   org.freedesktop.portal.Flatpak

# Testar em qualquer app Flatpak
flatpak run it.mijorus.gearlever    # Gear Lever
flatpak run org.mozilla.firefox     # Firefox (upload de arquivo)
flatpak run org.gimp.GIMP           # GIMP (abrir/salvar)
```

## Notas Adicionais

- A correção beneficia **todo o sistema** — todos os apps Flatpak na sessão Hyprland
- Em GNOME/KDE, o `graphical-session.target` é ativado automaticamente pelo desktop environment, portanto o problema não ocorre
- O problema e a solução são idênticos para **qualquer** app Flatpak que precise do file chooser
