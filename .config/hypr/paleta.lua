-- Cores do Hyprland que seguem o tema do quickshell (ver ~/.config/quickshell/aparencia.sh).
-- A paleta ativa fica em ~/.local/state/quickshell/aparencia/paleta; o aparencia.sh troca o arquivo
-- e roda `hyprctl reload`. Sem o arquivo, fica no Catppuccin Mocha.

local mocha = require("mocha")

local paletas = {
  ["catppuccin-mocha"] = {
    destaque      = mocha.mauve,      -- borda da janela em foco
    inativa       = mocha.surface2,   -- borda das outras janelas
    redimensionar = mocha.peach,      -- borda durante o modo de redimensionar
  },
  ["gruvbox-escuro"] = {
    destaque      = 0xfffe8019,       -- orange
    inativa       = 0xff504945,       -- bg2
    redimensionar = 0xfffabd2f,       -- yellow
  },
  ["gruvbox-claro"] = {
    destaque      = 0xffaf3a03,       -- orange
    inativa       = 0xffbdae93,       -- bg3
    redimensionar = 0xffb57614,       -- yellow
  },
}

local nome = "catppuccin-mocha"
local f = io.open((os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/quickshell/aparencia/paleta", "r")
if f then
  nome = (f:read("l") or ""):gsub("%s+", "")
  f:close()
end

return paletas[nome] or paletas["catppuccin-mocha"]
