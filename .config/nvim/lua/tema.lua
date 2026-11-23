-- Tema do Neovim segue o tema do quickshell (~/.config/quickshell/aparencia.sh): Catppuccin Mocha ou
-- Gruvbox escuro/claro. A paleta fica em ~/.local/state/quickshell/aparencia/paleta; ao trocar, o
-- aparencia.sh chama aplicar() em cada nvim aberto (nvim --server … --remote-expr).
local M = {}

local arquivo = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/quickshell/aparencia/paleta"

local esquemas = {
	["catppuccin-mocha"] = { background = "dark", colorscheme = "catppuccin-mocha" },
	["gruvbox-escuro"] = { background = "dark", colorscheme = "gruvbox" },
	["vinho"] = { background = "dark", colorscheme = "vinho" },
	["gruvbox-claro"] = { background = "light", colorscheme = "gruvbox" },
}

function M.paleta()
	local f = io.open(arquivo, "r")
	if not f then
		return "catppuccin-mocha"
	end
	local p = (f:read("l") or ""):gsub("%s+", "")
	f:close()
	return esquemas[p] and p or "catppuccin-mocha"
end

function M.aplicar()
	local e = esquemas[M.paleta()]
	vim.o.background = e.background
	if not pcall(vim.cmd.colorscheme, e.colorscheme) then
		pcall(vim.cmd.colorscheme, "catppuccin-mocha")
	end
	return e.colorscheme
end

return M
