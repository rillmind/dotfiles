return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		require("toggleterm").setup({
			size = function()
				return math.floor(vim.o.lines * 0.25)
			end,
			direction = "horizontal",
		})

		vim.keymap.set("n", "<leader>t", "<cmd>ToggleTerm<CR>", { desc = "Toggle Terminal" })
		-- <C-\> no terminal: <leader>t aqui fazia todo espaço digitado esperar o timeoutlen
		vim.keymap.set("t", "<C-\\>", "<cmd>ToggleTerm<CR>", { desc = "Toggle Terminal" })
	end,
}
