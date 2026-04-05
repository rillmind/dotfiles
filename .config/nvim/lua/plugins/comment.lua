return {
	"numToStr/Comment.nvim",
	event = "VeryLazy",
	opts = {
		-- add any options here
	},
	config = function()
		require("Comment").setup()

		local cm = require("Comment.api")
		vim.keymap.set("n", "<leader>c", cm.toggle.linewise.current, { desc = "Toggle comment" })
		vim.keymap.set("v", "<leader>c", "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", { desc = "Toggle comment" })
	end,
}
