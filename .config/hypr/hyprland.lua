-- Hyprland configuration (Lua, Hyprland >= 0.57)
-- Migrada do hyprland.conf antigo; backup em ~/dotfiles/.config/hypr-hyprlang-backup/
-- Referência da API: /usr/share/hypr/stubs/hl.meta.lua e https://wiki.hypr.land/configuring/

-- cores das bordas seguem o tema do quickshell (Catppuccin Mocha ou Gruvbox claro/escuro)
local c = require("paleta")

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "0x0", scale = 2 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60", position = "0x0", scale = 1.25 })

hl.monitor({ output = "eDP-1", disabled = true })
hl.monitor({ output = "eDP-1", mode = "1920x1080@120", position = "0x1080", scale = 1 })

-- Escolhas confirmadas no menu de monitores do quickshell (modules/DisplayManager.qml) valem por
-- cima das regras acima. Para voltar a usar só as regras acima, apague este arquivo.
pcall(dofile, os.getenv("HOME") .. "/.local/state/hypr/monitors.lua")

--hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/hypr/desktop-portals.sh")
  hl.exec_cmd("udiskie --tray")
  -- papel de parede: aplicado pelo tema do quickshell (tema.sh iniciar → aparencia.sh), um por tema
  hl.exec_cmd(
    [[hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' && sleep 1 && hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })']])
  hl.exec_cmd("sudo systemctl start tailscaled")
  hl.exec_cmd("flatpak run md.obsidian.Obsidian")
  hl.exec_cmd("gammastep")
  -- vibrância da TV: aplica no login e sempre que o HDMI é conectado (valor no script)
  hl.exec_cmd("~/.config/hypr/scripts/nvibrant-hdmi.sh")
  hl.exec_cmd("nohup flatpak run com.nextcloud.desktopclient.nextcloud --background &")
  -- hl.exec_cmd("syncthing")  -- já iniciado pelo serviço systemd (syncthing.service, --no-browser)
  -- hl.exec_cmd("dunst")  -- notificações agora são do quickshell (modules/Notifications.qml de cada tema)
  hl.exec_cmd("ckb-next -b")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("swayidle -w before-sleep ~/.config/quickshell-bloqueio/bloquear.sh")
  hl.exec_cmd("~/.config/quickshell-apps/apps.sh iniciar")  -- menu de apps (Super+A)
  -- hl.exec_cmd("waybar")
  -- tema salvo do quickshell (pastas em ~/.config/quickshell; troca com SUPER+SHIFT+T)
  -- sobe depois que a janela do Obsidian aparece (até 15s): carregar o ícone dele faz o quickshell
  -- cair, e o tema.sh reinicia sozinho quando isso acontece
  hl.exec_cmd([[for i in $(seq 30); do hyprctl clients | grep -qiE 'class: .*obsidian' && break; sleep 0.5; done; ~/.config/quickshell/tema.sh iniciar]])
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd([[hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })']])
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
  -- hl.exec_cmd("~/.config/hypr/scripts/dock-smart.sh")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

-- Antigo `exec` (roda no início e a cada reload)
local function on_every_load()
  hl.exec_cmd("sh ~/.config/hypr/scripts/get-last-focused-window.sh")
  -- hl.exec_cmd("eww daemon")
end
hl.on("hyprland.start", on_every_load)
hl.on("config.reloaded", on_every_load)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
  general = {
    gaps_in     = c.gaps_in,   -- espaços e arredondamento vêm da paleta do tema (paleta.lua)
    gaps_out    = c.gaps_out,
    border_size = 2,

    col         = {
      active_border   = c.destaque,
      inactive_border = c.inativa,
    },

    layout      = "dwindle",
  },

  decoration = {
    rounding = c.rounding,

    blur = {
      enabled = true,
      xray    = false,
      size    = 8,
      passes  = 3,   -- desfoque forte (estilo GNOME) no menu de apps; não há janelas transparentes
    },
  },

  cursor = {
    no_hardware_cursors = true,
  },

  binds = {
    workspace_back_and_forth = false,
  },

  -- VRR só em tela cheia (jogos): a tela do eDP-1 suporta. Em tudo (1) pode piscar no desktop.
  misc = {
    vrr = 2,
    allow_session_lock_restore = true,  -- a tela de bloqueio (quickshell-bloqueio) pode subir de novo se cair
  },

  animations = {
    enabled = false,
  },
})

-- vidro fosco para quickshell (barra + popups + dock) – catppuccin mocha
-- hl.layer_rule({ match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0.2 })

-- menu de apps (Super+A): fundo desfocado, estilo GNOME
hl.layer_rule({ match = { namespace = "quickshell-apps" }, blur = true })

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("myBezier2", { type = "bezier", points = { { 0.65, 0 }, { 0.35, 1 } } })
hl.curve("slow", { type = "bezier", points = { { 0, 0.85 }, { 0.3, 1 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.7, 0.6 }, { 0.1, 1.1 } } })
hl.curve("bounce", { type = "bezier", points = { { 1, 1.6 }, { 0.1, 0.85 } } })
hl.curve("slingshot", { type = "bezier", points = { { 1, -1 }, { 0.15, 1.25 } } })
-- "nice" não é mais aceita (pontos limitados a 2.0) e não era usada em nenhuma animação
-- hl.curve("nice",      { type = "bezier", points = { {0, 6.9},     {0.5, -4.20} } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "bounce", style = "popin" })
hl.animation({ leaf = "border", enabled = true, speed = 20, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slide" })

---------------
---- INPUT ----
---------------

hl.config({
  input = {
    kb_layout          = "br,us",
    kb_variant         = "",
    kb_model           = "",
    kb_options         = "grp:win_space_toggle",
    kb_rules           = "",
    numlock_by_default = true,
    accel_profile      = "flat",

    follow_mouse       = 1,

    touchpad           = {
      natural_scroll = true,
    },

    sensitivity        = 0.1,
  },
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "ALT"

-- Tampa do notebook: nunca suspende (logind com HandleLidSwitch=ignore em
-- /etc/systemd/logind.conf.d/10-lid-ignore.conf, instalado por ~/.scripts/linux/lid-ignore.sh),
-- só apaga a tela e tudo segue rodando.
-- Com monitor externo, desativa o eDP-1 para as janelas irem para o outro monitor.
local function has_external_monitor()
  for _, m in ipairs(hl.get_monitors()) do
    if m.name ~= "eDP-1" then return true end
  end
  return false
end
hl.bind("switch:on:Lid Switch", function()
  if has_external_monitor() then
    hl.monitor({ output = "eDP-1", disabled = true })
  else
    hl.dispatch(hl.dsp.dpms({ action = "disable", monitor = "eDP-1" }))
  end
end, { locked = true })
hl.bind("switch:off:Lid Switch", function()
  local edp = hl.get_monitor("eDP-1")
  if not edp or not edp.enabled then
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
  end
  hl.dispatch(hl.dsp.dpms({ action = "enable", monitor = "eDP-1" }))
end, { locked = true })

-- Sem monitor externo, reativa o eDP-1 para a sessão não ficar sem tela. disabled = false é obrigatório:
-- as regras se somam por saída, e o disabled = true lá de cima continuaria valendo.
local laptop_screen_auto_on = false
local function ensure_laptop_screen()
  if has_external_monitor() or hl.get_monitor("eDP-1") then return end
  laptop_screen_auto_on = true
  hl.monitor({ output = "eDP-1", disabled = false, mode = "1920x1080@120", position = "0x1080", scale = 1 })
end
hl.on("monitor.removed", ensure_laptop_screen)
-- Carregar a config sem externo: as regras lá de cima desativariam o eDP-1 e a tela ficaria preta.
-- Esta regra vem depois delas, então vale por cima. (Um hl.on("config.reloaded") roda cedo demais:
-- o eDP-1 ainda está ligado nessa hora e só é desligado depois.)
if not has_external_monitor() then
  laptop_screen_auto_on = true
  hl.monitor({ output = "eDP-1", disabled = false, mode = "1920x1080@120", position = "0x1080", scale = 1 })
end
-- Ao religar um externo, desfaz a ativação acima; se o eDP-1 já estava ligado antes, ele continua ligado.
hl.on("monitor.added", function()
  if not laptop_screen_auto_on or not has_external_monitor() then return end
  laptop_screen_auto_on = false
  hl.monitor({ output = "eDP-1", disabled = true })
end)

hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + U", hl.dsp.exec_cmd("~/.config/quickshell-bloqueio/bloquear.sh"))
hl.bind("SUPER + I", hl.dsp.exec_cmd("codium ~/.config/hypr/"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("eww open --toggle calendar"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("eww open --toggle powermenu"))
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("~/.config/hypr/window-switcher.sh"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- launcher do tema ativo do quickshell; o wofi antigo era: wofi --hide-scroll --width=600px
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("~/.config/quickshell/tema.sh ipc launcher toggle"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- menu de apps em tela cheia (~/.config/quickshell-apps)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("~/.config/quickshell-apps/apps.sh toggle"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("~/.config/quickshell/tema.sh ipc launcher power"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("eww open --toggle overview && eww update selected=_none"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/wofi-emoji/wofi-emoji"))
hl.bind(mainMod .. " + F10", hl.dsp.pass({ window = [[class:^(com\.obsproject\.Studio)$]] }))
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("flatpak run io.missioncenter.MissionCenter"))

-- hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp)" "$HOME/Pictures/screenshots/$(date +'%s_grim.png')"]]))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | wl-copy]]))

-- quickshell: troca de tema (Catppuccin-mocha ⇄ Gruvbox) e modo claro/escuro do Gruvbox
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("~/.config/quickshell/tema.sh trocar"))
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("~/.config/quickshell/tema.sh ipc gruvbox modo"))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl -- set-sink-volume @DEFAULT_SINK@ +5%"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl -- set-sink-volume @DEFAULT_SINK@ -5%"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

-- Modo de redimensionar: borda laranja enquanto ativo
hl.bind(mainMod .. " + R", function()
  hl.config({ general = { col = { active_border = c.redimensionar } } })
  hl.dispatch(hl.dsp.submap("resize"))
end)
hl.define_submap("resize", function()
  hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("escape", function()
    hl.config({ general = { col = { active_border = c.destaque } } })
    hl.dispatch(hl.dsp.submap("reset"))
  end)
end)

hl.bind(mainMod .. " + F11", function()
  hl.monitor({ output = "DP-2", mode = "3840x2160@60", position = "0x0", scale = 1.25 })
end)
hl.bind(mainMod .. " + F12", function()
  hl.monitor({ output = "DP-2", mode = "3840x2160@60", position = "0x0", scale = 1 })
end)

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + minus", hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:special" }))  -- era Super+A

-- Workspaces 1-10 (tecla 0 = workspace 10)
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- SUPER + SHIFT + N: move o workspace atual para o monitor N
-- (monitores numerados por posição: da esquerda para a direita, depois de cima para baixo)
for i = 1, 9 do
  hl.bind("SUPER + SHIFT + " .. i, function()
    local mons = {}
    for _, m in ipairs(hl.get_monitors()) do
      if m.enabled and not m.is_mirror then table.insert(mons, m) end
    end
    table.sort(mons, function(a, b)
      if a.x ~= b.x then return a.x < b.x end
      return a.y < b.y
    end)
    if mons[i] then
      hl.dispatch(hl.dsp.workspace.move({ monitor = mons[i].name }))
    end
  end)
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))

-------------------------
---- WINDOW RULES -------
-------------------------

-- Regras que estavam comentadas no config antigo:
-- hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true, max_size = "600 800", center = true })
-- hl.window_rule({ match = { class = "^(libreoffice)$" }, tile = true })
-- hl.window_rule({ match = { class = "^(blueman-manager)$" }, float = true })
-- hl.window_rule({ match = { class = "^(org.gnome.Calculator)$" }, float = true, size = "490 600" })
-- hl.window_rule({ match = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, float = true })
