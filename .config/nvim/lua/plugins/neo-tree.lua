return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	-- cmd = "Neotree",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("neo-tree").setup({
			filesystem = {
				filtered_items = {
					visible = true,
					show_hidden_count = true,
					hide_dotfiles = false,
					hide_gitignored = true,
					never_show = {
						".DS_Store",
						"thumbs.db",
					},
				},
				follow_current_file = {
					enabled = true,
				},
				use_libuv_file_watcher = true,
			},
			window = {
				position = "right",
				width = 35,
			},
			default_component_configs = {
				icon = {
					folder_closed = "",
					folder_open = "",
					folder_empty = "ﰊ",
				},
			},
		})

		vim.keymap.set("n", "<M-e>", ":Neotree filesystem position=right reveal toggle<CR>", { desc = "File Explorer" })
	end,
}
