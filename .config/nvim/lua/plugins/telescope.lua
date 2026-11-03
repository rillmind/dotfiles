return {
	{
		"nvim-telescope/telescope.nvim",
		-- master: a 0.1.6 usa ft_to_lang do nvim-treesitter antigo e quebra o previewer
		branch = "master",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-ui-select.nvim",
		},
		config = function()
			local builtin = require("telescope.builtin")

			require("telescope").setup({
				defaults = {
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})

			require("telescope").load_extension("ui-select")

			vim.keymap.set("n", "<leader>p", builtin.find_files, { desc = "Find Files" })
			vim.keymap.set("n", "<leader>fg", builtin.buffers, { desc = "Find Buffers" })
			vim.keymap.set("n", "<leader>g", builtin.live_grep, { desc = "Live Grep" })
		end,
	},
}
