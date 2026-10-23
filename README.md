# dotfiles

Meus arquivos de configuração do Linux (e alguns do Windows), versionados para montar o mesmo
ambiente em qualquer máquina.

## O que faz

O repositório espelha a minha pasta pessoal (`~`). Os principais conteúdos:

- **Shell e terminal**: `.zshrc` (com antigen), `.bashrc`, `.tmux.conf` e `.config/tmux`,
  `starship.toml`, oh-my-posh, Alacritty, Kitty e Ghostty;
- **Editores**: Neovim, LunarVim, Helix, Zed e VSCodium;
- **Ambientes gráficos**: Hyprland, Sway, i3, Waybar, Polybar, Rofi, Wofi, Quickshell, Eww,
  Dunst e configurações do COSMIC e do GNOME (`.gnome-extensions`, `.dconf_backup.txt`);
- **Temas**: quase tudo em Catppuccin (GTK 3/4, btop, Spicetify, Zathura, Yazi, cursores em
  `.icons`, temas em `.themes`) e fontes em `.fonts`;
- **Scripts** em `.scripts/linux` (pós-instalação do Fedora e do Arch, limpeza de caches,
  instalação de Flatpaks, Homebrew, Rust etc.) e `.scripts/windows` (PowerShell);
- **Anotações** em `.docs` (drivers da NVIDIA, Docker no Fedora, Wi-Fi etc.);
- `.config/Windows`, `.config/alacrittyWindows` e `.config/komorebi`: configurações do Windows
  (GlazeWM, YASB, Windows Terminal).

Os scripts de pós-instalação são chamados pelo [new-distro](https://github.com/rillmind/new-distro),
um menu de terminal em Go.

## Por que existe

Para não reconfigurar tudo à mão a cada distro nova ou reinstalação: clono o repositório, aplico
os links e o ambiente (shell, editor, temas, atalhos) volta igual.

## Instalação

Pré-requisitos: git e [GNU Stow](https://www.gnu.org/software/stow/) (`sudo dnf install stow`).
O repositório precisa ficar em `~/dotfiles`: os links são relativos e o new-distro procura os
scripts nesse caminho.

```sh
git clone https://github.com/rillmind/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -n -v .   # simulação: mostra os links que seriam criados, sem mudar nada
stow .         # cria em ~ os links para os arquivos do repositório
```

O `stow` não sobrescreve arquivos que já existem em `~` (como um `.bashrc` padrão): ele avisa do
conflito e para. Mova ou apague esses arquivos antes. Para desfazer, `stow -D .`.

Os scripts de `.scripts` não rodam sozinhos e alteram o sistema (instalam pacotes, mudam
configurações); leia cada um antes de executar.

## Como testar

Para conferir sem mexer na sua pasta pessoal, aplique os links num diretório temporário:

```sh
mkdir -p /tmp/home-teste/.config
cp -r ~/dotfiles /tmp/home-teste/dotfiles
cd /tmp/home-teste/dotfiles && stow .
ls -la /tmp/home-teste            # .zshrc -> dotfiles/.zshrc, .tmux.conf -> dotfiles/.tmux.conf ...
readlink /tmp/home-teste/.config/nvim   # ../dotfiles/.config/nvim
```

Para conferir a sintaxe dos arquivos de shell sem executá-los:

```sh
zsh -n .zshrc && bash -n .bashrc
for f in .scripts/linux/*.sh .scripts/linux/*/*.sh; do bash -n "$f" || echo "erro em $f"; done
```

Depois de aplicar na máquina de verdade, abra um terminal novo e veja se o prompt, os temas e os
atalhos do tmux carregam.
