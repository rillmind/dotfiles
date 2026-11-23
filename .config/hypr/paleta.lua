-- Cores, espaços e arredondamento do Hyprland que seguem o tema do quickshell (ver ~/.config/quickshell/aparencia.sh).
-- A paleta ativa fica em ~/.local/state/quickshell/aparencia/paleta; o aparencia.sh troca o arquivo
-- e roda `hyprctl reload`. Sem o arquivo, fica no Catppuccin Mocha.

local mocha = require("mocha")

local paletas = {
  ["catppuccin-mocha"] = {
    destaque      = mocha.mauve,      -- borda da janela em foco
    inativa       = mocha.surface2,   -- borda das outras janelas
    redimensionar = mocha.peach,      -- borda durante o modo de redimensionar
    gaps_in       = 6,                -- espaço entre janelas
    gaps_out      = 8,                -- espaço entre janelas e a borda da tela
    rounding      = 5,                -- arredondamento das janelas
  },
  ["gruvbox-escuro"] = {
    destaque      = 0xfffe8019,       -- orange
    inativa       = 0xff504945,       -- bg2
    redimensionar = 0xfffabd2f,       -- yellow
    gaps_in       = 0,
    gaps_out      = 0,                -- janelas coladas no contorno e na barra do quickshell
    rounding      = 10,
  },
  ["gruvbox-claro"] = {
    destaque      = 0xffaf3a03,       -- orange
    inativa       = 0xffbdae93,       -- bg3
    redimensionar = 0xffb57614,       -- yellow
    gaps_in       = 0,
    gaps_out      = 0,                -- janelas coladas no contorno e na barra do quickshell
    rounding      = 10,
  },
}

paletas["vinho"] = {
  destaque      = 0xff8c2f4b,       -- vinho
  inativa       = 0xff35151f,
  redimensionar = 0xffd9a862,       -- dourado
  gaps_in       = 0,
  gaps_out      = 0,
  rounding      = 0,
  fundo         = 0xff15070d,       -- sem papel de parede: cor sólida
}

local nome = "catppuccin-mocha"
local f = io.open((os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/quickshell/aparencia/paleta", "r")
if f then
  nome = (f:read("l") or ""):gsub("%s+", "")
  f:close()
end

return paletas[nome] or paletas["catppuccin-mocha"]
