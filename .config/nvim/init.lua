local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)

require("vim-options")
require("lazy").setup("plugins")
-- colorscheme do tema do quickshell (Catppuccin ou Gruvbox); ver lua/tema.lua
require("tema").aplicar()

vim.keymap.set("n", "<leader>w", ":wa<CR>", { desc = "Salvar todos os buffers" })

vim.keymap.set("n", "<leader>q", function()
	-- Fecha o NeoTree se estiver aberto
	pcall(function()
		vim.cmd("Neotree close")
	end)
	-- Sai do Neovim
	vim.cmd("q")
end, { desc = "Fechar NeoTree e sair do Neovim" })
