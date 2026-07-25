return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "echasnovski/mini.icons",
	config = function()
		local bufferline = require("bufferline")

		local custom_icons = {
			[".gitignore"] = "󰊢",
			["package.json"] = "",
			["tsconfig.json"] = "",
			["Makefile"] = "",
		}

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

		local mini_icons = require("mini.icons")

		bufferline.setup({
			options = {
				mode = "buffers",
				separator_style = "padded",
				show_buffer_icons = true,
				show_buffer_close_icons = true,
				show_close_icon = true,
				show_tab_indicators = true,
				persist_buffer_sort = true,
				enforce_regular_tabs = false,
				always_show_bufferline = true,
				diagnostics = "nvim_lsp",
				diagnostics_indicator = function(count, level)
					local icon = level:match("error") and " " or " "
					return " " .. icon .. count
				end,
				offsets = {
					{
						filetype = "neo-tree",
						text = " neo-tree",
						highlight = "Directory",
						text_align = "left",
					},
				},
				get_element_icon = function(element)
					local name = vim.fn.fnamemodify(element.path, ":t")
					local ext = vim.fn.fnamemodify(element.path, ":e")

					-- Check custom filename icons first (same as neo-tree)
					if custom_icons[name] then
						return custom_icons[name], "MiniIconsBlue"
					end

					-- Check extension icons (same as neo-tree)
					if ext and ext_icons[ext] then
						return ext_icons[ext], "MiniIconsBlue"
					end

					-- Fallback to mini.icons
					local icon, hl = mini_icons.get("file", name)
					return icon, hl
				end,
			},
		})

		-- Keymaps
		vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Próximo buffer" })
		vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Buffer anterior" })
		vim.keymap.set("n", "<leader>h", "<cmd>BufferLineCyclePrev<cr>", { desc = "Buffer anterior" })
		vim.keymap.set("n", "<leader>l", "<cmd>BufferLineCycleNext<cr>", { desc = "Próximo buffer" })
		vim.keymap.set("n", "<leader>b", ":BufferLine<cr>", {})
		vim.keymap.set("n", "<leader>bc", "<cmd>BufferLinePickClose<cr>", { desc = "Fechar buffer selecionado" })
		vim.keymap.set("n", "<leader>bb", "<cmd>BufferLinePick<cr>", { desc = "Selecionar buffer" })
		vim.keymap.set("n", "<leader>bh", "<cmd>BufferLineCloseLeft<cr>", { desc = "Fechar abas a esquerda" })
		vim.keymap.set("n", "<leader>bl", "<cmd>BufferLineCloseRight<cr>", { desc = "Fechar abas a direita" })
		vim.keymap.set("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Fechar as outras abas" })
	end,
}
