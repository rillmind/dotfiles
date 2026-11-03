-- Hyprland configuration (Lua, Hyprland >= 0.57)
-- Migrada do hyprland.conf antigo; backup em ~/dotfiles/.config/hypr-hyprlang-backup/
-- Referência da API: /usr/share/hypr/stubs/hl.meta.lua e https://wiki.hypr.land/configuring/

local c = require("mocha")

------------------
---- MONITORS ----
------------------

--hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "0x0", scale = 2 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60", position = "0x0", scale = 1.33 })
--hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@120", position = "0x0", scale = 1 })

hl.monitor({ output = "eDP-1", disabled = true })
--hl.monitor({ output = "eDP-1", mode = "1920x1080@120", position = "0x1080", scale = 1 })

--hl.workspace_rule({ workspace = "1", monitor = "eDP-1", default = true })

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/hypr/desktop-portals.sh")
  hl.exec_cmd("udiskie --tray")
  hl.exec_cmd("swaybg -i /home/raul/Nextcloud/Imagens/Wallpapers/blobs-d.png")
  hl.exec_cmd(
    [[hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' && sleep 1 && hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })']])
  hl.exec_cmd("sudo systemctl start tailscaled")
  hl.exec_cmd("flatpak run md.obsidian.Obsidian")
  hl.exec_cmd("gammastep")
  hl.exec_cmd("bash /home/raul/.scripts/linux/NvibrantStart")
  hl.exec_cmd("nohup flatpak run com.nextcloud.desktopclient.nextcloud --background &")
  -- hl.exec_cmd("syncthing")  -- já iniciado pelo serviço systemd (syncthing.service, --no-browser)
  hl.exec_cmd("dunst")
  hl.exec_cmd("ckb-next -b")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("swayidle -w before-sleep swaylock")
  -- hl.exec_cmd("waybar")
  hl.exec_cmd("quickshell")
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
    gaps_in     = 6,
    gaps_out    = 8,
    border_size = 2,

    col         = {
      active_border   = c.mauve,
      inactive_border = c.surface2,
    },

    layout      = "dwindle",
  },

  decoration = {
    rounding = 5,

    blur = {
      enabled = true,
      xray    = false,
    },
  },

  cursor = {
    no_hardware_cursors = true,
  },

  binds = {
    workspace_back_and_forth = false,
  },

  animations = {
    enabled = false,
  },
})

-- vidro fosco para quickshell (barra + popups + dock) – catppuccin mocha
-- hl.layer_rule({ match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0.2 })

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

-- Tampa do notebook
hl.bind("switch:on:Lid Switch", function()
  hl.monitor({ output = "eDP-1", disabled = true })
end, { locked = true })
hl.bind("switch:off:Lid Switch", function()
  hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
end, { locked = true })

hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + U", hl.dsp.exec_cmd("swaylock"))
hl.bind("SUPER + I", hl.dsp.exec_cmd("codium ~/.config/hypr/"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("eww open --toggle calendar"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("eww open --toggle powermenu"))
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("~/.config/hypr/window-switcher.sh"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- launcher do quickshell (modules/Launcher.qml); o wofi antigo era: wofi --hide-scroll --width=600px
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + A", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("quickshell ipc call launcher power"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("eww open --toggle overview && eww update selected=_none"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("~/wofi-emoji/wofi-emoji"))
hl.bind(mainMod .. " + F10", hl.dsp.pass({ window = [[class:^(com\.obsproject\.Studio)$]] }))
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("flatpak run io.missioncenter.MissionCenter"))

-- hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp)" "$HOME/Pictures/screenshots/$(date +'%s_grim.png')"]]))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | wl-copy]]))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl -- set-sink-volume @DEFAULT_SINK@ +5%"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl -- set-sink-volume @DEFAULT_SINK@ -5%"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

-- Modo de redimensionar: borda laranja enquanto ativo
hl.bind(mainMod .. " + R", function()
  hl.config({ general = { col = { active_border = c.peach } } })
  hl.dispatch(hl.dsp.submap("resize"))
end)
hl.define_submap("resize", function()
  hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("escape", function()
    hl.config({ general = { col = { active_border = c.mauve } } })
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
