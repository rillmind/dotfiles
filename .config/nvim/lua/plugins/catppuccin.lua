return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
  opts = {
    transparent_background = false,
    term_colors = true,
    integrations = {
      treesitter = true,
      cmp = true,
      lsp_trouble = true,
      gitsigns = true,
      telescope = true,
      which_key = true,
      indent_blankline = { enabled = true },
      native_lsp = {
        enabled = true,
        virtual_text = true,
        underlines = true,
        inlay_hints = true,
      },
    },
    custom_highlights = function(C)
      return {
        ["@operator"] = { fg = C.rosewater },
        ["@keyword.operator"] = { fg = C.rosewater },
        ["@punctuation.delimiter"] = { fg = C.overlay2 },
        ["@punctuation.bracket"] = { fg = C.overlay2 },
        ["@parameter"] = { fg = C.peach },
        ["@property"] = { fg = C.green },
        ["@variable"] = { fg = C.text },
        ["@variable.builtin"] = { fg = C.red },
        ["@number"] = { fg = C.peach },
        ["@boolean"] = { fg = C.peach },
        ["@type"] = { fg = C.yellow },
        ["@type.qualifier"] = { fg = C.mauve },
        ["@string.special"] = { fg = C.teal },
        ["@method"] = { fg = C.blue },
        NeoTreeNormal = { bg = C.mantle },
        NeoTreeNormalNC = { bg = C.mantle },
        MiniIconsAzure = { fg = C.mauve },
        MiniIconsBlue = { fg = C.mauve },
        MiniIconsCyan = { fg = C.mauve },
        MiniIconsGreen = { fg = C.mauve },
        MiniIconsGrey = { fg = C.mauve },
        MiniIconsOrange = { fg = C.mauve },
        MiniIconsPurple = { fg = C.mauve },
        MiniIconsRed = { fg = C.mauve },
        MiniIconsYellow = { fg = C.mauve },
      }
    end,
  },
}
