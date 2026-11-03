return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      local ts = require("nvim-treesitter")

      ts.install({ "go", "python", "javascript", "typescript", "tsx", "rust", "toml", "json" })

      local function enable(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        if pcall(vim.treesitter.start, buf, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      -- Highlight + indent, instalando o parser automaticamente se faltar
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(args.match)
          if not lang then
            return
          end
          if vim.tbl_contains(ts.get_installed(), lang) then
            enable(args.buf, lang)
          elseif vim.tbl_contains(ts.get_available(), lang) then
            ts.install(lang):await(function()
              enable(args.buf, lang)
            end)
          else
            enable(args.buf, lang) -- parsers que vêm com o nvim (lua, vim, markdown...)
          end
        end,
      })

      -- Seleção incremental (nativa do nvim 0.12: `an` expande, `in` reduz)
      vim.keymap.set("n", "<C-space>", "van", { remap = true, desc = "Start node selection" })
      vim.keymap.set("x", "<C-space>", "an", { remap = true, desc = "Expand node selection" })
      vim.keymap.set("x", "<bs>", "in", { remap = true, desc = "Shrink node selection" })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")

      local selects = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
      }
      for key, query in pairs(selects) do
        vim.keymap.set({ "x", "o" }, key, function()
          select.select_textobject(query, "textobjects")
        end, { desc = "Select " .. query })
      end

      local moves = {
        goto_next_start = { ["]m"] = "@function.outer", ["]]"] = "@class.outer" },
        goto_next_end = { ["]M"] = "@function.outer", ["]["] = "@class.outer" },
        goto_previous_start = { ["[m"] = "@function.outer", ["[["] = "@class.outer" },
        goto_previous_end = { ["[M"] = "@function.outer", ["[]"] = "@class.outer" },
      }
      for fn, maps in pairs(moves) do
        for key, query in pairs(maps) do
          vim.keymap.set({ "n", "x", "o" }, key, function()
            move[fn](query, "textobjects")
          end, { desc = fn .. " " .. query })
        end
      end
    end,
  },
}
