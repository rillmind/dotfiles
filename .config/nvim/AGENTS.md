# Neovim config — notas para agentes

Histórico completo, motivos e changelog: `~/dotfiles/.docs/nvim-config.md`. Leia antes de mudar plugins.

- Neovim 0.12 (linuxbrew). lazy.nvim, um spec por arquivo em `lua/plugins/`. `~/.config/nvim` → `~/dotfiles/.config/nvim`.
- O usuário escreve em português; comentários e `desc` de keymaps também em português.
- Estilo: a maioria dos arquivos usa tabs; `lsp-config.lua`, `none-ls.lua`, `tree-sitter.lua` e `catppuccin.lua` usam 2 espaços. Siga o arquivo que estiver editando.

## Restrições (aprendidas na prática)

- **nvim-treesitter e textobjects ficam no branch `main`**. Não existe `require("nvim-treesitter.configs")` nem opções no `setup()`. Highlight/indent são ligados por autocmd `FileType` em `tree-sitter.lua`. O `master` está congelado e não suporta o nvim 0.12.
- **Telescope fica no branch `master`**. A tag 0.1.x chama `nvim-treesitter.parsers.ft_to_lang`, que não existe no `main`, e quebra o previewer. Foi por isso que o previewer chegou a ficar desligado.
- Compilar parsers exige o CLI `tree-sitter`, que vem do npm via **nvm**. Sem o nvm no PATH, `install()` falha.
- none-ls: só entra formatter cujo binário esteja instalado (`condition` + `executable`). stylua, black, isort, gofumpt e prettier **não** estão instalados. O format-on-save usa um augroup único com limpeza por buffer e prefere o none-ls ao LSP.
- Não reintroduza `vim.diagnostic.goto_*` (obsoleto); use `vim.diagnostic.jump`.

## Como testar sem abrir a UI

```bash
nvim --headless "+Lazy! install" +qa                      # instala plugins novos
nvim --headless arquivo.go "+lua vim.defer_fn(function()
  print(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil)
  print(vim.api.nvim_exec2('messages',{output=true}).output); vim.cmd('qa!') end, 3000)"
```

Para trocar o branch de um plugin: `:Lazy! update <nome>`. Depois, commitar o `lazy-lock.json` junto.
