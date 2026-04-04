return {
	"echasnovski/mini.icons",
	version = false,
	config = function()
		require("mini.icons").setup({
			file = {
				[".gitignore"] = { glyph = "󰊢", hl = "MiniIconsGrey" },
			},
			filetype = {
				neo_tree = { glyph = "", hl = "MiniIconsGreen" },
			},
		})
	end,
}
