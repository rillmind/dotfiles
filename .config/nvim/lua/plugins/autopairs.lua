return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	config = function()
		require("nvim-autopairs").setup({
			disable_filetype = { "TelescopePrompt", "spectre_panel" },
			disable_in_macro = true,
			disable_in_visualblock = false,
			ignored_next_char = "[%w%%%'%[\"%.]",
			enable_check_bracket_line = true,
			enable_afterquote = true,
			enable_moveright = true,
		})
	end,
}
