return {
  "nvimtools/none-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvimtools/none-ls-extras.nvim",
  },
  config = function()
    local null_ls = require("null-ls")

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

        -- JSON (via prettier)
        null_ls.builtins.formatting.prettier,
      },
      on_attach = function(client, bufnr)
        if client:supports_method("textDocument/formatting") then
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("FormatOnSave", { clear = true }),
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format({ bufnr = bufnr })
            end,
          })
        end
      end,
    })

    vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, { desc = "Format" })
  end,
}
