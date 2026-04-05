return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	-- cmd = "Neotree",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"echasnovski/mini.icons",
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
					folder_empty = "",
					icons = {
						[".gitignore"] = "󰊢",
						["package.json"] = "",
						["tsconfig.json"] = "",
						["Makefile"] = "",
						["lua"] = "",
						["py"] = "",
						["js"] = "",
						["ts"] = "󰛦",
						["tsx"] = "",
						["jsx"] = "",
						["go"] = "",
						["rs"] = "",
						["toml"] = "",
						["json"] = "",
						["yaml"] = "",
						["yml"] = "",
						["md"] = "",
						["sh"] = "",
						["bash"] = "",
						["zsh"] = "",
						["html"] = "",
						["css"] = "",
						["scss"] = "",
						["vim"] = "",
						["png"] = "",
						["jpg"] = "",
						["svg"] = "",
						["lock"] = "",
					},
					provider = function(icon, node)
						local name = node.name
						local ext = name:match("^.+%.(.+)$")
						local custom_icons = {
							[".gitignore"] = "󰊢",
							["package.json"] = "",
							["tsconfig.json"] = "",
							["Makefile"] = "",
						}

						if custom_icons[name] then
							icon.text = custom_icons[name]
							icon.highlight = "MiniIconsBlue"
							return
						end

						local ext_icons = {
							["lua"] = "",
							["py"] = "",
							["js"] = "",
							["ts"] = "󰛦",
							["tsx"] = "",
							["jsx"] = "",
							["go"] = "",
							["rs"] = "",
							["toml"] = "",
							["json"] = "",
							["yaml"] = "",
							["yml"] = "",
							["md"] = "",
							["sh"] = "",
							["bash"] = "",
							["zsh"] = "",
							["html"] = "",
							["css"] = "",
							["scss"] = "",
							["vim"] = "",
							["png"] = "",
							["jpg"] = "",
							["svg"] = "",
							["lock"] = "",
						}

						if ext and ext_icons[ext] then
							icon.text = ext_icons[ext]
							icon.highlight = "MiniIconsBlue"
						end
					end,
				},
			},
		})

		vim.keymap.set("n", "<M-e>", ":Neotree filesystem position=right reveal toggle<CR>", { desc = "File Explorer" })
	end,
}
