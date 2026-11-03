# Configuração do Neovim

Config em `~/dotfiles/.config/nvim` (o `~/.config/nvim` aponta pra cá). Gerenciador de plugins: **lazy.nvim**, um arquivo por plugin em `lua/plugins/`.

---

## 1. Estado antes da revisão de 2026-10-21

Snapshot: commit `37d2724` do dotfiles (os arquivos do nvim não tinham mudanças locais). Para voltar:

```bash
git -C ~/dotfiles checkout 37d2724 -- .config/nvim
nvim --headless "+Lazy! restore" +qa
```

- Neovim **0.12.6** (Fedora 44).
- `nvim-treesitter` fixado no branch **`master`** com `require("nvim-treesitter").setup({...})`. No `master`, essa função **não recebe opções**, então `ensure_installed`, `indent`, `incremental_selection` e textobjects eram ignorados. O highlight só funcionava por causa do autocmd `FileType` → `vim.treesitter.start`.
- `nvim-treesitter-textobjects` no branch `main` (API nova, incompatível com o `master` do treesitter).
- Telescope fixado na tag `0.1.6` com `previewer = false`.
- none-ls: só `taplo` e `prettier` ativos; stylua, black, isort, gofumpt, goimports e rustfmt comentados. O `prettier` **não estava instalado**.
- Format-on-save: o augroup `FormatOnSave` era recriado com `clear = true` a cada attach, então só o último buffer formatava ao salvar.
- nvim-cmp com a fonte `buffer`, mas o plugin `cmp-buffer` não estava instalado.
- Keymaps com prefixo em comum (`<leader>b`/`<leader>bc`…, `<leader>f`/`<leader>fg`, `<leader>c`/`<leader>ca`) e `<leader>t` em modo terminal, o que fazia o espaço esperar o `timeoutlen`.
- APIs obsoletas: `vim.diagnostic.goto_prev/goto_next`, `float.source = "always"`.
- `updatetime` padrão (4000 ms), então o popup de diagnóstico no `CursorHold` demorava 4 s.

### Por que as coisas estavam desligadas (reconstruído pelo git)

| O quê | Quando | Motivo |
| --- | --- | --- |
| `previewer = false` no Telescope | 2026-04-05 (`f57c736`) | Na época o treesitter estava no `main`. O Telescope **0.1.6** chama `require("nvim-treesitter.parsers").ft_to_lang`, que só existe no `master`, e o previewer quebrava. |
| treesitter `main` → `master` | 2026-07-25 (`b3d5241`) | Provavelmente pelo mesmo conflito com o Telescope 0.1.6 e outros plugins que esperam a API antiga. O `master` está congelado e não acompanha o Neovim 0.12. |
| formatters do none-ls comentados | 2026-07-05 (`5c0f361`) | Provavelmente porque os binários (stylua, black, isort, prettier, gofumpt) não estavam instalados e o none-ls dava erro. |

---

## 2. O que mudou na revisão de 2026-10-21

| Arquivo | Mudança |
| --- | --- |
| `lua/plugins/tree-sitter.lua` | Treesitter e textobjects no branch **`main`**. Os parsers são instalados com `require("nvim-treesitter").install{...}`. Um autocmd `FileType` liga highlight e indent e instala o parser se faltar (substitui o `auto_install`). Textobjects (`af`/`if`/`ac`/`ic`, `]m`/`[m`/`]]`/`[[`…) remapeados para a API nova. A seleção incremental usa o recurso nativo do nvim 0.12 (`an`/`in`): `<C-space>` expande e `<BS>` reduz. |
| `lua/plugins/telescope.lua` | Saiu da tag `0.1.6` para o branch `master` (usa `vim.treesitter.language.get_lang`). **Previewer religado.** Novo `<leader>g` = live grep. |
| `lua/plugins/none-ls.lua` | Augroup `FormatOnSave` criado uma vez, com limpeza por buffer (todos os buffers formatam ao salvar). Se o none-ls formata o buffer, só ele é usado; senão, o LSP. `prettier` só entra se estiver instalado. |
| `lua/plugins/completions.lua` | Adicionado `hrsh7th/cmp-buffer` (a fonte `buffer` já estava configurada). |
| `lua/plugins/lsp-config.lua` | `vim.diagnostic.jump()` no lugar de `goto_prev/next`. `float.source = true`. `mason-lspconfig` depende do `mason`. |
| `lua/vim-options.lua` | `number` veio do `init.lua`. `updatetime = 250`. |
| `init.lua` | Removido o `highlight LineNr` (o catppuccin sobrescrevia, nunca teve efeito). Para usar, coloque em `custom_highlights` no `catppuccin.lua`. |
| `lua/plugins/bufferline.lua` | Removido o `<leader>b` → `:BufferLine` (comando inexistente, que atrasava os `<leader>b*`). |
| `lua/plugins/toggle-term.lua` | No modo terminal, o toggle virou `<C-\>` (antes era `<leader>t`, que atrasava cada espaço). No modo normal continua `<leader>t`. |

Testado em modo headless: highlight e indent ativos num `.go`, gopls conectado, `vaf` e `]m` funcionando, Telescope abrindo, format-on-save em dois buffers TOML ao mesmo tempo, nenhuma mensagem de erro no startup.

## 3. Cuidados para o futuro

- **Compilar parsers** (treesitter `main`) exige o CLI `tree-sitter` e um compilador C. Aqui o `tree-sitter` vem do **npm via nvm** (`~/.nvm/versions/node/*/bin`). Se o nvim for aberto sem o nvm no PATH (ex.: por um atalho do desktop), instalar parser novo falha. Os já instalados ficam em `~/.local/share/nvim/site/parser/` e continuam funcionando.
- **Não voltar o Telescope para a tag 0.1.x** enquanto o treesitter estiver no `main`, senão o previewer quebra de novo (`ft_to_lang`).
- O branch `master` do nvim-treesitter está congelado e não suporta o nvim 0.12. Não voltar para ele.
- Formatters comentados no none-ls (stylua, black, isort, gofumpt, goimports): os binários não estão instalados. Para religar, instale primeiro (`:Mason` ou o gerenciador do sistema). Go já formata com gofumpt pelo `gopls` (`gofumpt = true`). O `rustfmt` não é mais builtin do none-ls; o rust-analyzer já formata.
- Prefixos de keymap ainda em comum (causam o pequeno atraso do `timeoutlen`): `<leader>f` / `<leader>fg` e `<leader>c` / `<leader>ca`. Foram mantidos de propósito.
- O nvim 0.11+ já tem por padrão `grn`, `gra`, `grr`, `gri`, `K`, `[d`/`]d` e `gc` (comentários).

## 4. Pendências opcionais

- Os ícones estão duplicados 3 vezes (`neo-tree.lua` ×2 e `bufferline.lua`), e o catppuccin pinta todos os `MiniIcons*` de mauve. Dá para juntar tudo num `lua/icons.lua`.
- O dashboard usa `nvim-web-devicons`, enquanto o resto usa `mini.icons`. Daria para usar `MiniIcons.mock_nvim_web_devicons()`.
- O Comment.nvim pode ser trocado pelo `gc` nativo.
- `.luarc.json`: as globals `version`/`inoremap` parecem resto de outro projeto. Considerar o `folke/lazydev.nvim`.
