# Vinho

Fundo vinho escuro, texto creme-rosado, destaques em vinho claro, dourado e sálvia. Tudo quadrado:
sem cantos arredondados, sem sombras, sem espaços entre janelas. Fonte: JetBrains Mono.

## Fundos

| Nome | Hex | Uso |
|---|---|---|
| profundo | `#15070d` | fundo da área de trabalho, barra do tmux, bordas escuras |
| fundo | `#1c0b12` | terminal, barra, launcher, notificações, janelas |
| elevado | `#28111a` | menus, campos, linha do cursor |
| superfície | `#35151f` | hover, borda de janela inativa, notificação crítica |
| borda | `#4a1d2c` | divisórias, seleção discreta |
| borda forte | `#5f2c3c` | bordas em destaque, números de linha |
| seleção | `#5a2236` | item selecionado, texto selecionado |
| vinho | `#8c2f4b` | workspace ativo, borda da janela em foco, molduras |

## Texto

| Nome | Hex | Uso |
|---|---|---|
| texto | `#e8d5cf` | texto principal |
| claro | `#f6e9e2` | texto sobre vinho ou seleção |
| rosado | `#d8bfba` | texto secundário claro |
| suave | `#c9aaab` | itens de lista, informações da barra |
| apagado | `#b08d94` | workspaces inativos, texto secundário |
| tênue | `#8a646c` | comentários, desabilitado |

## Cores

| Nome | Hex | Clara (ANSI 9–14) | Uso |
|---|---|---|---|
| destaque | `#c4527a` | `#dc7396` | cursor, prompt, palavras-chave |
| vermelho | `#e0566f` | `#ee7489` | erro, crítico |
| dourado | `#d9a862` | `#e8bf80` | aviso, busca, números, modo de redimensionar |
| sálvia | `#a3ad7a` | `#b9c48d` | sucesso, textos (strings), bateria carregando |
| azul | `#93a3c0` | `#abbad4` | funções, pastas, links externos |
| água | `#8fb0a4` | `#a6c6ba` | tipos |
| rosa | `#c99ab8` | | especiais, itálico |

## Terminal (ANSI)

| # | Normal | | # | Clara |
|---|---|---|---|---|
| 0 | `#35151f` | | 8 | `#8a646c` |
| 1 | `#e0566f` | | 9 | `#ee7489` |
| 2 | `#a3ad7a` | | 10 | `#b9c48d` |
| 3 | `#d9a862` | | 11 | `#e8bf80` |
| 4 | `#93a3c0` | | 12 | `#abbad4` |
| 5 | `#c4527a` | | 13 | `#dc7396` |
| 6 | `#8fb0a4` | | 14 | `#a6c6ba` |
| 7 | `#d8bfba` | | 15 | `#f6e9e2` |

Fundo `#1c0b12` · texto `#e8d5cf` · cursor `#c4527a` · seleção `#5a2236` / `#f6e9e2`

## Só em alguns apps

| Hex | Onde |
|---|---|
| `#2b2a1c` `#2a1f2d` `#46324c` | diff do Neovim (adicionado, alterado, trecho alterado) |
| `#d0688c` `#d98968` | Obsidian: links/títulos (mais claro, para contraste) e laranja |
| `#c08d4a` `#87925f` `#7686a6` `#b03a52` `#a0729a` | btop (tons escuros dos gradientes) |

## Onde estão

- Esta pasta: barra (`barra.css`, `bandeja.css`), launcher (`fuzzel.ini`, `wofi.css`), avisos (`dunstrc`),
  terminal (`cores-ghostty`), bloqueio (`swaylock.conf`) e Hyprland (`hyprland.lua`, `hyprland.conf`)
- Em `~/.config`: `ghostty/themes/vinho`, `tmux/temas/vinho.conf`, `gtk-4.0/temas/vinho.css`,
  `yazi/temas/vinho.toml`, `zathura/vinho`, `btop/themes/vinho.theme`, `swaylock/vinho`,
  `wofi/colors/vinho.css`, `nvim/colors/vinho.lua` e `hypr/paleta.lua`
- Obsidian: `~/dev/obsidian-vinho` (tem também uma versão clara)
