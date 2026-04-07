return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					-- Lua
					"lua_ls",
					-- Python
					"pyright",
					-- JavaScript / TypeScript
					"ts_ls",
					-- Go
					"gopls",
					-- Rust
					"rust_analyzer",
					-- TOML
					"taplo",
					-- JSON
					"jsonls",
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			-- Lua
			vim.lsp.config.lua_ls = {
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
					},
				},
			}

			-- Python
			vim.lsp.config.pyright = {}

			-- JavaScript / TypeScript
			vim.lsp.config.ts_ls = {
				init_options = {
					plugins = {},
				},
			}

			-- Go
			vim.lsp.config.gopls = {
				settings = {
					gopls = {
						gofumpt = true,
						codelenses = {
							gc_details = false,
							generate = true,
							regenerate_cgo = true,
							run_govulncheck = true,
							test = true,
							tidy = true,
							upgrade_dependency = true,
							vendor = true,
						},
					},
				},
			}

			-- Rust
			vim.lsp.config.rust_analyzer = {
				settings = {
					["rust-analyzer"] = {
						check = {
							command = "clippy",
						},
					},
				},
			}

			-- TOML
			vim.lsp.config.taplo = {}

			-- JSON
			vim.lsp.config.jsonls = {
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enable = true },
					},
				},
			}

			-- Habilitar todos
			vim.lsp.enable({
				"lua_ls",
				"pyright",
				"ts_ls",
				"gopls",
				"rust_analyzer",
				"taplo",
				"jsonls",
			})

			-- Keymaps
			vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, { desc = "Rename" })
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })

			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "LSP Hover" })
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })
			vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic" })
			vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to Implementation" })
			vim.keymap.set("n", "[e", function()
				vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
			end, { desc = "Prev Error" })
			vim.keymap.set("n", "]e", function()
				vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
			end, { desc = "Next Error" })

			-- Diagnostic config: mostra popup ao passar o cursor
			vim.diagnostic.config({
				virtual_text = true,
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					source = "always",
					header = { "", "" },
					prefix = "",
				},
			})

			-- Auto-show diagnostic popup quando o cursor estiver na linha
			local diagnostic_popup = vim.api.nvim_create_augroup("DiagnosticPopup", { clear = true })
			vim.api.nvim_create_autocmd("CursorHold", {
				group = diagnostic_popup,
				callback = function()
					vim.diagnostic.open_float(nil, { focus = false })
				end,
			})
		end,
	},
	-- schemastore para JSON schemas
	{
		"b0o/schemastore.nvim",
		lazy = true,
	},
}
