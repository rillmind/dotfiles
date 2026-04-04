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
		vim.keymap.set("t", "<leader>t", "<cmd>ToggleTerm<CR>", { desc = "Toggle Terminal" })
	end,
}
