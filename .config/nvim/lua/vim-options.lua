vim.g.mapleader = " "

-- Configuração do clipboard para Wayland
vim.opt.clipboard = "unnamedplus"

vim.opt.scrolloff = 5
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

vim.opt.fillchars:append({ eob = " " })

-- Pular linhas visuais em vez de lógicas
vim.keymap.set("n", "j", "gj", { desc = "Move down (visual lines)" })
vim.keymap.set("n", "k", "gk", { desc = "Move up (visual lines)" })

-- Focar no neo-tree com Alt+e
vim.keymap.set("n", "<M-e>", "<c-w>w")
