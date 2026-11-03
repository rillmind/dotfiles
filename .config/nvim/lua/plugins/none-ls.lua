return {
  "nvimtools/none-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvimtools/none-ls-extras.nvim",
  },
  config = function()
    local null_ls = require("null-ls")

    -- Se o none-ls formata o buffer, usa só ele (evita brigar com ts_ls etc.); senão, o LSP
    local function format(bufnr)
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local has_null_ls = #vim.lsp.get_clients({
        bufnr = bufnr,
        name = "null-ls",
        method = "textDocument/formatting",
      }) > 0
      vim.lsp.buf.format({
        bufnr = bufnr,
        filter = function(client)
          return not has_null_ls or client.name == "null-ls"
        end,
      })
    end

    local format_group = vim.api.nvim_create_augroup("FormatOnSave", { clear = true })

    null_ls.setup({
      sources = {
        -- Lua
        -- null_ls.builtins.formatting.stylua,
        --
        -- -- Python
        -- null_ls.builtins.formatting.black,
        -- null_ls.builtins.formatting.isort,
        --
        -- -- JavaScript / TypeScript
        -- null_ls.builtins.formatting.prettier,
        --
        -- -- Go
        -- null_ls.builtins.formatting.gofumpt,
        -- null_ls.builtins.formatting.goimports,

        -- -- Rust
        -- null_ls.builtins.formatting.rustfmt,

        -- TOML (via none-ls-extras)
        require("none-ls.formatting.taplo"),

        -- JSON (via prettier) — só se estiver instalado (`npm i -g prettier`)
        null_ls.builtins.formatting.prettier.with({
          condition = function()
            return vim.fn.executable("prettier") == 1
          end,
        }),
      },
      on_attach = function(client, bufnr)
        if client:supports_method("textDocument/formatting") then
          vim.api.nvim_clear_autocmds({ group = format_group, buffer = bufnr })
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = format_group,
            buffer = bufnr,
            callback = function()
              format(bufnr)
            end,
          })
        end
      end,
    })

    vim.keymap.set("n", "<leader>f", function()
      format()
    end, { desc = "Format" })
  end,
}
