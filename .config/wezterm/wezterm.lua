-- ~/.config/wezterm/wezterm.lua
-- Terminal do Windows. Replica o ~/.tmux.conf (atalhos sem prefixo, copy mode vi,
-- barra no topo estilo catppuccin "rounded") usando o multiplexador do próprio WezTerm.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Catppuccin Mocha
local c = {
  base = '#1e1e2e', mantle = '#181825', crust = '#11111b',
  surface0 = '#313244', surface1 = '#45475a', overlay0 = '#6c7086',
  text = '#cdd6f4', subtext0 = '#a6adc8',
  mauve = '#cba6f7', pink = '#f5c2e7', green = '#a6e3a1',
  peach = '#fab387', blue = '#89b4fa', yellow = '#f9e2af',
}

-- Sessões persistentes (como o tmux): as abas vivem no wezterm-mux-server e
-- continuam rodando ao fechar a janela. Ctrl+Shift+D desanexa.
-- Se der problema, mude para false e o WezTerm volta a ser um terminal comum.
local persistir_sessoes = true

-- --- Shell e janela ---

config.default_prog = { 'pwsh.exe', '-NoLogo' }

config.color_scheme = 'Catppuccin Mocha'
config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 16

config.window_decorations = 'RESIZE'
config.window_padding = { left = 2, right = 2, top = 0, bottom = 0 }
config.win32_system_backdrop = 'Acrylic'
config.window_background_opacity = 0.95
config.window_close_confirmation = 'NeverPrompt'

config.default_cursor_style = 'SteadyBlock'
config.cursor_blink_rate = 0 -- nem quando o programa pede cursor piscando
config.hide_mouse_cursor_when_typing = true
config.audible_bell = 'Disabled'
config.scrollback_lines = 10000

-- Painel inativo um pouco apagado, divisória discreta
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }
config.colors = {
  split = c.overlay0,
  tab_bar = { background = c.mantle },
}

if persistir_sessoes then
  config.unix_domains = { { name = 'unix' } }
  config.default_gui_startup_args = { 'connect', 'unix' }
end

-- --- Barra de abas (status-position top + catppuccin rounded) ---

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32

local esq, dir = '\u{e0b6}', '\u{e0b4}' -- meias-luas do Nerd Font

local function basename(s)
  return (s:gsub('[/\\]+$', ''):match('([^/\\]+)$')) or s
end

-- Nome da aba: o título que o programa definiu (ex.: Claude Code); para o shell,
-- cujo título é o caminho (oh-my-posh), mostra só a pasta atual.
local function titulo_da_aba(tab)
  if tab.tab_title ~= '' then return tab.tab_title end
  local pane = tab.active_pane
  local processo = basename(pane.foreground_process_name or ''):gsub('%.exe$', '')
  local titulo = pane.title
  if processo == 'pwsh' or processo == 'powershell' or titulo:find '[/\\]' then
    titulo = basename(titulo:gsub('^%s+', ''))
  end
  if titulo == '' then titulo = processo end
  return titulo
end

wezterm.on('format-tab-title', function(tab, _, _, _, _, max_width)
  local cor = tab.is_active and c.mauve or c.overlay0
  local fg = tab.is_active and c.text or c.subtext0
  local zoom = tab.active_pane.is_zoomed and ' \u{f531}' or ''
  local titulo = wezterm.truncate_right(titulo_da_aba(tab), max_width - 8) .. zoom
  return {
    { Background = { Color = c.mantle } }, { Foreground = { Color = cor } }, { Text = esq },
    { Background = { Color = cor } }, { Foreground = { Color = c.crust } }, { Text = (tab.tab_index + 1) .. ' ' },
    { Background = { Color = c.surface0 } }, { Foreground = { Color = fg } }, { Text = ' ' .. titulo },
    { Background = { Color = c.mantle } }, { Foreground = { Color = c.surface0 } }, { Text = dir .. ' ' },
  }
end)

local function pilula(cor, icone, texto)
  return {
    { Background = { Color = c.mantle } }, { Foreground = { Color = cor } }, { Text = ' ' .. esq },
    { Background = { Color = cor } }, { Foreground = { Color = c.crust } }, { Text = icone .. ' ' },
    { Background = { Color = c.surface0 } }, { Foreground = { Color = c.text } }, { Text = ' ' .. texto },
    { Background = { Color = c.mantle } }, { Foreground = { Color = c.surface0 } }, { Text = dir },
  }
end

-- Direita: modo (cópia/busca) + aplicação + sessão, como o status-right do tmux
wezterm.on('update-status', function(window, pane)
  local itens = {}
  local modo = window:active_key_table()
  if modo == 'copy_mode' then
    for _, e in ipairs(pilula(c.yellow, '\u{f0c5}', 'cópia')) do table.insert(itens, e) end
  elseif modo == 'search_mode' then
    for _, e in ipairs(pilula(c.yellow, '\u{f002}', 'busca')) do table.insert(itens, e) end
  end
  local processo = basename(pane:get_foreground_process_name() or ''):gsub('%.exe$', '')
  if processo ~= '' then
    for _, e in ipairs(pilula(c.pink, '\u{f489}', processo)) do table.insert(itens, e) end
  end
  for _, e in ipairs(pilula(c.green, '\u{f0c9}', window:active_workspace())) do table.insert(itens, e) end
  table.insert(itens, { Text = ' ' })
  window:set_right_status(wezterm.format(itens))
end)

-- --- Atalhos (equivalentes ao tmux com prefix None) ---

-- Ctrl+C copia se houver seleção; senão manda o Ctrl+C normal (interromper)
local copiar_ou_interromper = wezterm.action_callback(function(window, pane)
  if window:get_selection_text_for_pane(pane) ~= '' then
    window:perform_action(act.CopyTo 'Clipboard', pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
  end
end)

config.keys = {
  -- Abas (janelas do tmux)
  { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'q', mods = 'CTRL', action = act.CloseCurrentTab { confirm = false } },
  { key = 'h', mods = 'CTRL', action = act.ActivateTabRelative(-1) },
  { key = 'l', mods = 'CTRL', action = act.ActivateTabRelative(1) },
  { key = 'LeftArrow', mods = 'SHIFT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'SHIFT', action = act.ActivateTabRelative(1) },
  { key = 'h', mods = 'CTRL|SHIFT', action = act.MoveTabRelative(-1) },
  { key = 'l', mods = 'CTRL|SHIFT', action = act.MoveTabRelative(1) },

  -- Painéis
  { key = 'h', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CTRL|ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'u', mods = 'CTRL', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'i', mods = 'CTRL', action = act.SplitPane { direction = 'Down', size = { Percent = 30 } } },
  { key = 'z', mods = 'CTRL', action = act.TogglePaneZoomState },

  -- Copy mode (vi) e área de transferência
  { key = 'v', mods = 'CTRL', action = act.ActivateCopyMode },
  { key = 'c', mods = 'CTRL', action = copiar_ou_interromper },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },

  -- Shift+Enter: nova linha no Claude Code
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\x1b\r' },

  -- Sessões (workspaces): Ctrl+Shift+S escolhe, Ctrl+Shift+E cria/renomeia
  { key = 's', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { key = 'e', mods = 'CTRL|SHIFT', action = act.PromptInputLine {
    description = 'Nome da sessão (nova ou existente):',
    action = wezterm.action_callback(function(window, pane, nome)
      if nome and nome ~= '' then
        window:perform_action(act.SwitchToWorkspace { name = nome }, pane)
      end
    end),
  } },
  { key = 'r', mods = 'CTRL|ALT', action = act.PromptInputLine {
    description = 'Renomear aba:',
    action = wezterm.action_callback(function(window, _, nome)
      if nome then window:active_tab():set_title(nome) end
    end),
  } },
}

if persistir_sessoes then
  table.insert(config.keys, { key = 'd', mods = 'CTRL|SHIFT', action = act.DetachDomain { DomainName = 'unix' } })
end

-- Ctrl+1..9 vão direto para a aba (como no Windows Terminal)
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'CTRL', action = act.ActivateTab(i - 1) })
end

-- Botão direito cola (hábito do Windows Terminal)
config.mouse_bindings = {
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = act.PasteFrom 'Clipboard' },
}

-- Copy mode: padrões do WezTerm (v, Ctrl+V retangular, y copia, Esc sai) + busca do tmux
if wezterm.gui then
  local tabelas = wezterm.gui.default_key_tables()
  local buscar = act.Multiple { act.CopyMode 'ClearPattern', act.CopyMode 'EditPattern' }
  for _, k in ipairs {
    { key = '/', mods = 'NONE', action = buscar },
    { key = '?', mods = 'NONE', action = buscar },
    { key = '?', mods = 'SHIFT', action = buscar },
    { key = 'n', mods = 'NONE', action = act.CopyMode 'NextMatch' },
    { key = 'N', mods = 'NONE', action = act.CopyMode 'PriorMatch' },
    { key = 'N', mods = 'SHIFT', action = act.CopyMode 'PriorMatch' },
  } do
    table.insert(tabelas.copy_mode, k)
  end
  -- Enter na busca confirma e volta ao copy mode (como no tmux)
  table.insert(tabelas.search_mode, { key = 'Enter', mods = 'NONE', action = act.CopyMode 'AcceptPattern' })
  config.key_tables = tabelas
end

return config
