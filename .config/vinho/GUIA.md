# Guia do Vinho

Como sair de um Fedora recém-instalado para um Hyprland usável em poucos minutos e, depois, para a
configuração completa com os três temas (Catppuccin, Gruvbox e Vinho).

- [1. Como funciona](#1-como-funciona)
- [2. Do zero ao Vinho simples](#2-do-zero-ao-vinho-simples)
- [3. Instalação manual, sem o script](#3-instalação-manual-sem-o-script)
- [4. Atalhos](#4-atalhos)
- [5. Barra](#5-barra)
- [6. Launcher](#6-launcher)
- [7. Da versão simples para a completa](#7-da-versão-simples-para-a-completa)
- [8. Comandos do dia a dia](#8-comandos-do-dia-a-dia)
- [9. Personalizar](#9-personalizar)
- [10. Desfazer](#10-desfazer)
- [11. Problemas comuns](#11-problemas-comuns)

---

## 1. Como funciona

| | Etapa 1: simples | Etapa 2: completa |
|---|---|---|
| **Para quê** | usar o PC enquanto instala o resto | o ambiente de sempre |
| **Comando** | `instalar.sh` | `instalar.sh --completo` |
| **Hyprland** | `~/.config/vinho/hyprland.lua` (ou `.conf`) | `~/.config/hypr/hyprland.lua` |
| **Temas** | Vinho | Catppuccin, Gruvbox e Vinho (`Super+Shift+T`) |
| **Precisa de** | Hyprland, quickshell, Ghostty e utilitários pequenos | o resto dos programas |

Barra, launcher, painéis, notificações e tela de bloqueio são todos do **quickshell**. Não há waybar,
dunst, rofi, wofi nem swaylock no caminho.

O script só cria **links** para o `~/dotfiles` e nunca apaga nada: o que já existir no lugar vira
`*.antes-do-vinho.<data>`. Por isso, **não apague nem mova o `~/dotfiles`** depois de instalar.

---

## 2. Do zero ao Vinho simples

### 2.1 Atualizar o sistema e instalar o git

```bash
sudo dnf upgrade --refresh
sudo dnf install git
```

Se o `upgrade` trouxe um kernel novo, reinicie antes de continuar.

### 2.2 Instalar o Hyprland

Ele não está nos repositórios oficiais do Fedora, então vem de um COPR:

```bash
sudo dnf copr enable sdegler/hyprland
sudo dnf install hyprland xdg-desktop-portal-hyprland
```

Confira a versão (a partir da 0.57 a config é em Lua; antes, `.conf`; o script escolhe sozinho):

```bash
Hyprland --version
```

### 2.3 Baixar o dotfiles e instalar

```bash
git clone https://github.com/rillmind/dotfiles ~/dotfiles
~/dotfiles/.config/vinho/instalar.sh
```

O script pede a senha do `sudo` e faz, nesta ordem:

1. instala `quickshell grim slurp wl-clipboard brightnessctl wireplumber upower procps-ng NetworkManager gawk`;
2. instala o Ghostty pelo COPR `scottames/ghostty`, se ele ainda não existir;
3. liga `~/.config/vinho`, `quickshell`, `quickshell-bloqueio`, `quickshell-apps` e `~/.fonts`;
4. deixa o Vinho como tema ativo;
5. liga a config mínima do Hyprland em `~/.config/hypr/`.

### 2.4 Entrar

- **Com tela de login (GDM, SDDM):** escolha a sessão **Hyprland** e entre.
- **Sem tela de login:** num TTY, rode:

  ```bash
  start-hyprland
  ```

- **Já dentro do Hyprland:** o script recarrega tudo na hora.

### 2.5 Primeiros passos

| Quero | Faço |
|---|---|
| abrir o terminal | `Alt+Enter` |
| abrir um app | `Alt+Espaço` e digitar |
| conectar ao wifi | clicar em **sem rede** (ou `wifi`) na barra → Rede |
| ajustar resolução e escala | `Alt+Espaço` → `telas` |
| bloquear a tela | `Super+U` |
| desligar | `Alt+B` → Desligar → Enter duas vezes |

Teste o bloqueio (`Super+U`) uma vez logo no começo, com tudo salvo.

---

## 3. Instalação manual, sem o script

O mesmo resultado da etapa 1, passo a passo. Depois das seções 2.1 e 2.2:

```bash
# programas
sudo dnf install quickshell grim slurp wl-clipboard brightnessctl wireplumber upower procps-ng NetworkManager gawk
sudo dnf copr enable scottames/ghostty
sudo dnf install ghostty

# dotfiles
git clone https://github.com/rillmind/dotfiles ~/dotfiles

# links (se algum destino já existir, mova-o antes)
mkdir -p ~/.config/hypr ~/.local/state/quickshell/aparencia
ln -s ~/dotfiles/.config/vinho               ~/.config/vinho
ln -s ~/dotfiles/.config/quickshell          ~/.config/quickshell
ln -s ~/dotfiles/.config/quickshell-bloqueio ~/.config/quickshell-bloqueio
ln -s ~/dotfiles/.config/quickshell-apps     ~/.config/quickshell-apps
ln -s ~/dotfiles/.fonts                      ~/.fonts
ln -s ~/.config/vinho/hyprland.lua           ~/.config/hypr/hyprland.lua
fc-cache

# tema ativo
echo Vinho > ~/.local/state/quickshell/tema-ativo
echo vinho > ~/.local/state/quickshell/aparencia/paleta
```

No Hyprland anterior ao 0.57, troque o link do `hyprland.lua` por:

```bash
ln -s ~/.config/vinho/hyprland.conf ~/.config/hypr/hyprland.conf
```

> O `hyprland.conf` ainda não foi testado numa versão antiga do Hyprland.

### Só o quickshell

Para usar o quickshell sem o resto:

```bash
sudo dnf install quickshell
quickshell --version
quickshell -p ~/dotfiles/.config/quickshell/Vinho      # roda o tema direto, no terminal
```

`-p` aponta a pasta de uma config. Sem ele, o quickshell procura `~/.config/quickshell/shell.qml`, que
aqui não existe, porque cada tema tem a sua pasta.

---

## 4. Atalhos

`Alt` é a tecla principal. Os mesmos valem na versão completa, que tem outros além destes.

### Programas

| Atalho | Ação |
|---|---|
| `Alt+Enter` | terminal (Ghostty) |
| `Alt+Espaço` | launcher |
| `Super+A` | launcher (na completa: menu de apps em tela cheia) |
| `Alt+B` | energia |
| `Super+U` | bloquear a tela |
| `Super+E` | arquivos (Nautilus, se instalado) |
| `Super+Shift+S` | capturar uma área para a área de transferência |
| `Super+Espaço` | alternar o teclado entre br e us |
| `Super+Shift+T` | trocar de tema (**só na completa**) |

### Janelas

| Atalho | Ação |
|---|---|
| `Alt+H/J/K/L` | mudar o foco |
| `Alt+Shift+H/J/K/L` | mover a janela |
| `Alt+Shift+Q` | fechar |
| `Alt+V` | flutuar / encaixar |
| `Alt+F` | maximizar |
| `Alt+Shift+F` | tela cheia |
| `Alt+P` | pseudo-tile |
| `Alt+Tab` / `Alt+Shift+Tab` | próxima / anterior |
| `Alt+R` | redimensionar com `H/J/K/L` (borda dourada); `Esc` sai |
| `Super+arrastar` | mover (esquerdo) ou redimensionar (direito) |

### Workspaces

| Atalho | Ação |
|---|---|
| `Alt+1…0` | ir para o workspace 1 a 10 |
| `Alt+Shift+1…0` | levar a janela |
| `Alt+roda` ou `Alt+Ctrl+←/→` | anterior / próximo |
| `Alt+A` | guardar a janela na gaveta (workspace especial) |
| `Alt+-` | abrir / fechar a gaveta |
| `Alt+Shift+M` | **sair do Hyprland, sem confirmação** |

---

## 5. Barra

| Item | Clique | Botão direito | Roda |
|---|---|---|---|
| workspaces | ir | | trocar |
| título | menu da janela | menu da janela | |
| player (se houver) | painel de mídia | pausar | faixa anterior / próxima |
| avisos | notificações | não perturbe | |
| cpu, mem | central | processos | |
| wifi | central | rede | |
| vol | central | silenciar | volume |
| bat | central | bateria | |
| data | calendário com feriados | central | |
| ▲ | bandeja | energia | |

O botão do meio em **avisos** limpa as notificações; no **player**, passa de faixa. O menu do título só
funciona com a config em Lua. Um clique fora fecha qualquer painel.

---

## 6. Launcher

`Alt+Espaço`. Ignora maiúsculas e acentos, e os apps mais usados aparecem primeiro.

| Digite | Resultado |
|---|---|
| `local` | apps com esse nome, palavra-chave ou parecido |
| `=2*(3+4)^2` | calcula; Enter copia |
| `>` | sistema: bloquear, suspender, sair, reiniciar, desligar, painéis, tema |
| `som`, `rede`, `bluetooth`, `telas` | abre o painel direto |

| Tecla | Ação |
|---|---|
| `↓` `Tab` `Ctrl+N` | desce |
| `↑` `Shift+Tab` `Ctrl+P` | sobe |
| `PageUp` / `PageDown` | pula uma página |
| `Ctrl+U` | limpa |
| `Enter` | abre |
| `Esc` | fecha |

Sair, reiniciar e desligar pedem Enter duas vezes. **Suspender e bloquear não pedem.**

---

## 7. Da versão simples para a completa

### 7.1 Programas

Instale o que for usar. Os que a config chama:

```bash
sudo dnf install jq swaybg swayidle swaylock tmux neovim btop zathura zathura-pdf-mupdf socat flatpak pulseaudio-utils zenity wofi udiskie gammastep
```

| Programa | Para quê |
|---|---|
| `jq` | Catppuccin e Gruvbox (o script já instala) |
| `swaybg` | papel de parede (o script já instala) |
| `swayidle` | bloquear antes de suspender |
| `swaylock` | reserva, se a tela de bloqueio do quickshell falhar |
| `tmux` `neovim` `btop` `zathura` `yazi` | seguem as cores do tema |
| `zenity` | escolher o papel de parede pela central |
| `wofi` | trocador de janelas (`Super+Tab`) |
| `socat` | vibrância da TV e ventoinhas (específicos do notebook) |
| `pactl` (`pulseaudio-utils`) | teclas de volume da config completa |

O `yazi` não está nesta lista de instalação: instale pelo método que preferir.

### 7.2 Revisar antes de ligar

Abra o `~/dotfiles/.config/hypr/hyprland.lua`. Ele foi feito para o meu notebook, então ajuste se for
outra máquina:

- **monitores** (`eDP-1` e `HDMI-A-1`), no começo do arquivo;
- **NVIDIA**: remova as linhas `LIBVA_DRIVER_NAME` e `__GLX_VENDOR_LIBRARY_NAME` sem placa NVIDIA;
- **autostart**: Obsidian, Nextcloud, `nvibrant`, `ckb-next`, `tailscaled`.

### 7.3 Ligar

```bash
~/dotfiles/.config/vinho/instalar.sh --completo
```

Liga `hypr`, `ghostty`, `tmux`, `nvim`, `gtk-4.0`, `yazi`, `zathura`, `btop`, `swaylock`, `wofi`,
`~/.tmux.conf` e `~/.scripts`, e lista o que ainda não está instalado. Para não instalar o `jq` e o `swaybg`:

```bash
~/dotfiles/.config/vinho/instalar.sh --completo --sem-pacotes
```

Depois, **saia e entre de novo** no Hyprland, para o autostart completo rodar.

O `.zshrc` não faz parte disto; configure o shell à parte.

### 7.4 Obsidian e navegador

- **Obsidian:** tema em <https://github.com/rillmind/obsidian-vinho>. Para instalar à mão, copie
  `manifest.json` e `theme.css` para `<cofre>/.obsidian/themes/Vinho/`.
- **Sites (Stylus):** Gerenciar → Importar → `~/dotfiles/.themes/StylusVinhoImport.json` (ou
  `StylusGruvboxImport.json`). Deixe só um tema ativo.

---

## 8. Comandos do dia a dia

### Tema

```bash
~/.config/quickshell/tema.sh ativo             # tema atual
~/.config/quickshell/tema.sh lista             # temas disponíveis
~/.config/quickshell/tema.sh trocar            # próximo
~/.config/quickshell/tema.sh trocar Vinho      # um específico
~/.config/quickshell/tema.sh iniciar           # inicia ou reinicia o tema atual
```

### Aparência

```bash
~/.config/quickshell/aparencia.sh aplicar      # reaplica as cores em todos os apps
~/.config/quickshell/aparencia.sh wallpaper    # escolhe o papel de parede (precisa de zenity e swaybg)
~/.config/quickshell/aparencia.sh paleta       # paleta atual
```

Sem papel de parede escolhido, o fundo do Vinho é uma cor sólida do Hyprland.

### Abrir partes da interface

```bash
T=~/.config/quickshell/tema.sh
$T ipc launcher toggle
$T ipc launcher power                 # menu de energia
$T ipc launcher buscar "fire"         # abre já com uma busca
$T ipc panel open ""                  # central
$T ipc panel open network             # ou sound, battery, displays, fans, bluetooth
$T ipc panel popup cal                # ou sm, notif, media, tray
$T ipc panel close
$T ipc notificacoes naoPerturbe
$T ipc notificacoes limpar
$T ipc notificacoes central
```

`launcher buscar` e `panel popup` só existem no Vinho. Servem para criar atalhos no Hyprland:

```lua
hl.bind("SUPER + N", hl.dsp.exec_cmd("~/.config/quickshell/tema.sh ipc notificacoes central"))
```

### Bloqueio

```bash
~/.config/quickshell-bloqueio/bloquear.sh
```

### Atualizar

```bash
git -C ~/dotfiles pull
hyprctl reload
~/.config/quickshell/tema.sh iniciar
```

---

## 9. Personalizar

| O que mudar | Onde |
|---|---|
| cores da barra e dos painéis | `~/.config/quickshell/Vinho/modules/Theme.qml` |
| itens da barra | `~/.config/quickshell/Vinho/shell.qml` |
| launcher | `~/.config/quickshell/Vinho/modules/Launcher.qml` |
| tamanho dos avisos | `escala` em `~/.config/quickshell/Vinho/modules/Notifications.qml` |
| atalhos da versão simples | `~/.config/vinho/hyprland.lua` |
| atalhos da completa | `~/.config/hypr/hyprland.lua` |
| bordas e espaços por tema (completa) | `~/.config/hypr/paleta.lua` |
| terminal da versão simples | `~/.config/vinho/ghostty.conf` |
| todas as cores, com os hex | [CORES.md](CORES.md) |

O quickshell recarrega sozinho ao salvar um arquivo. O Hyprland também; para ver erros:

```bash
hyprctl configerrors
```

Para **criar outro tema**, copie uma pasta de `~/.config/quickshell/` e mude o nome: ela entra sozinha no
`Super+Shift+T`. Para as cores dos outros apps, acrescente a paleta no `aparencia.sh`.

---

## 10. Desfazer

Voltar da completa para a simples:

```bash
~/dotfiles/.config/vinho/instalar.sh --forcar
```

Voltar ao que existia antes: ache os backups, remova o link e devolva o original.

```bash
ls -d ~/.config/*.antes-do-vinho.* ~/.config/hypr/*.antes-do-vinho.* ~/*.antes-do-vinho.* ~/.*.antes-do-vinho.* 2>/dev/null

# exemplo com o ghostty (troque a data pela do seu backup)
rm ~/.config/ghostty
mv ~/.config/ghostty.antes-do-vinho.20261123-183339 ~/.config/ghostty
```

Use `rm` **sem** `-r` e sem barra no final: assim ele só remove o link, nunca o conteúdo do `~/dotfiles`.

---

## 11. Problemas comuns

**A barra não apareceu.** Reinicie o tema e leia o erro:

```bash
~/.config/quickshell/tema.sh iniciar
quickshell -p ~/.config/quickshell/Vinho log | tail -20
```

Ou rode em primeiro plano, depois de parar o que estiver rodando:

```bash
pkill -f "quickshell -p $HOME/.config/quickshell/"
quickshell -p ~/.config/quickshell/Vinho
```

**Ícones viram quadradinhos.** A fonte não foi encontrada:

```bash
fc-cache -f
fc-match "JetBrainsMono Nerd Font"      # deve responder JetBrainsMonoNerdFont-…
```

**"Hyprland não encontrado".** Volte à seção 2.2 e rode o `instalar.sh` de novo; os passos já feitos são
pulados.

**"Este PC já usa a config completa".** É uma proteção. Use `--forcar` só se quiser voltar à simples.

**Os avisos aparecem com outra cara.** Outro programa de notificações subiu antes:

```bash
busctl --user status org.freedesktop.Notifications | grep CommandLine
~/.config/quickshell/tema.sh iniciar      # encerra o dunst e assume
```

Se não for o dunst (mako, por exemplo), encerre-o antes.

**Wifi sempre "sem rede".** O item usa o NetworkManager:

```bash
systemctl status NetworkManager
nmcli device
```

**Volume não aparece.** O PipeWire precisa estar rodando:

```bash
systemctl --user status pipewire wireplumber
```

**Bateria não aparece.** Em desktop é o esperado. Em notebook:

```bash
systemctl status upower
upower -e
```

**Fiquei preso na tela de bloqueio.** Vá para outro terminal com `Ctrl+Alt+F3`, entre com seu usuário e rode
`loginctl`. Ache o número da sessão do Hyprland e encerre-a. **Isso fecha os programas abertos nela:**

```bash
loginctl
loginctl terminate-session NÚMERO
```

**A barra do tmux mostra símbolos estranhos.** Faltam as fontes próprias dela, ou o Ghostty abriu antes delas:

```bash
ls ~/.local/share/fonts/Tmux*.ttf
~/dotfiles/.config/vinho/instalar.sh --completo --sem-pacotes
```

Depois, abra uma janela nova do Ghostty.

**A barra lateral do tmux sumiu ou parou.** Apagar o `/tmp` remove o socket do tmux. Para recriar:

```bash
mkdir -p -m 700 /tmp/tmux-$UID; pkill -USR1 -x -u "$USER" 'tmux: server'
```

**NVIDIA com tela preta ou janelas pretas.** Costuma ser driver atualizado sem reiniciar. Reinicie.
