return {
	"nvimdev/dashboard-nvim",
	event = "VimEnter",
	config = function()
		local logo = {
			[[                                                                       ]],
			[[                                                                     ]],
			[[       ████ ██████           █████      ██                     ]],
			[[      ███████████             █████                             ]],
			[[      █████████ ███████████████████ ███   ███████████   ]],
			[[     █████████  ███    █████████████ █████ ██████████████   ]],
			[[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
			[[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
			[[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
			[[                                                                       ]],
		}

		local opts = {}
		opts.footer_margin = 0
		opts.autocenter = true

		require("dashboard").setup({
			config = {
				header = logo,
				center = {
					{
						icon = "󰊳 ",
						desc = "Update",
						action = "Lazy sync",
						key = "u",
					},
					{
						icon = " ",
						desc = "Find File",
						action = "Telescope find_files",
						key = "f",
					},
					{
						icon = " ",
						desc = "New File",
						action = "enew",
						key = "n",
					},
					{
						icon = " ",
						desc = "Recent Files",
						action = "Telescope oldfiles",
						key = "r",
					},
					{
						icon = "󰈭 ",
						desc = "Find Word",
						action = "Telescope live_grep",
						key = "g",
					},
				},
				footer = { "" },
				project = { enable = false },
			},
		})
	end,
	dependencies = { { "nvim-tree/nvim-web-devicons" } },
}
