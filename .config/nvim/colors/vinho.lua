-- Vinho: fundo vinho escuro, texto creme-rosado, destaques em vinho claro, dourado e sálvia.
vim.cmd("highlight clear")
vim.g.colors_name = "vinho"
local c = {
	bg = "#1c0b12", bg2 = "#28111a", s0 = "#35151f", s1 = "#4a1d2c", s2 = "#5f2c3c",
	fg = "#e8d5cf", sub = "#b08d94", gray = "#8a646c", accent = "#c4527a",
	red = "#e0566f", gold = "#d9a862", green = "#a3ad7a", blue = "#93a3c0", teal = "#8fb0a4", pink = "#c99ab8",
}
local function h(g, o) vim.api.nvim_set_hl(0, g, o) end
local grupos = {
	Normal = { fg = c.fg, bg = c.bg }, NormalFloat = { fg = c.fg, bg = c.bg2 }, FloatBorder = { fg = c.s2, bg = c.bg2 },
	CursorLine = { bg = c.bg2 }, CursorColumn = { bg = c.bg2 }, ColorColumn = { bg = c.bg2 }, Visual = { bg = "#5a2236" },
	LineNr = { fg = c.s2 }, CursorLineNr = { fg = c.gold, bold = true }, SignColumn = { bg = c.bg }, WinSeparator = { fg = c.s0 },
	StatusLine = { fg = c.fg, bg = c.s0 }, StatusLineNC = { fg = c.gray, bg = c.bg2 }, TabLine = { fg = c.sub, bg = c.bg2 },
	TabLineFill = { bg = c.bg2 }, TabLineSel = { fg = c.fg, bg = "#8c2f4b", bold = true },
	Pmenu = { fg = c.fg, bg = c.bg2 }, PmenuSel = { bg = "#5a2236", bold = true }, PmenuThumb = { bg = c.s2 },
	Search = { fg = c.bg, bg = c.gold }, IncSearch = { fg = c.bg, bg = c.accent }, CurSearch = { fg = c.bg, bg = c.accent },
	MatchParen = { fg = c.gold, bold = true, underline = true }, NonText = { fg = c.s2 }, Folded = { fg = c.sub, bg = c.bg2 },
	Directory = { fg = c.blue }, Title = { fg = c.accent, bold = true }, ErrorMsg = { fg = c.red }, WarningMsg = { fg = c.gold },
	Comment = { fg = c.gray, italic = true }, Constant = { fg = c.gold }, String = { fg = c.green }, Number = { fg = c.gold },
	Identifier = { fg = c.fg }, Function = { fg = c.blue }, Statement = { fg = c.accent }, Keyword = { fg = c.accent },
	Operator = { fg = c.sub }, PreProc = { fg = c.pink }, Type = { fg = c.teal }, Special = { fg = c.pink },
	Delimiter = { fg = c.sub }, Error = { fg = c.red }, Todo = { fg = c.bg, bg = c.gold, bold = true },
	["@variable"] = { fg = c.fg }, ["@property"] = { fg = "#d8bfba" },
	DiffAdd = { bg = "#2b2a1c" }, DiffChange = { bg = "#2a1f2d" }, DiffDelete = { fg = c.red, bg = "#35151f" }, DiffText = { bg = "#46324c" },
	Added = { fg = c.green }, Changed = { fg = c.blue }, Removed = { fg = c.red },
	DiagnosticError = { fg = c.red }, DiagnosticWarn = { fg = c.gold }, DiagnosticInfo = { fg = c.blue }, DiagnosticHint = { fg = c.teal },
}
for g, o in pairs(grupos) do h(g, o) end
