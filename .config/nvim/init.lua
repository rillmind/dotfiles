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

vim.wo.number = true
vim.cmd [[highlight LineNr guifg=#FFFFFF guibg=#000000 gui=bold]]

vim.opt.rtp:prepend(lazypath)

require("vim-options")
require("lazy").setup("plugins")

vim.keymap.set("n", "<leader>w", ":wa<CR>", {})

vim.keymap.set("n", "<leader>q", function()
	-- Fecha o NeoTree se estiver aberto
	pcall(function()
		vim.cmd("Neotree close")
	end)
	-- Sai do Neovim
	vim.cmd("q")
end, { desc = "Fechar NeoTree e sair do Neovim" })
