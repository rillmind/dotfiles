-- Hyprland mínimo com o tema Vinho do quickshell (Hyprland >= 0.57), para um PC recém-instalado: o
-- instalar.sh o liga em ~/.config/hypr/hyprland.lua. Mesmos atalhos do setup completo.
local tema = "~/.config/quickshell/tema.sh "
local bloquear = "~/.config/quickshell-bloqueio/bloquear.sh"
local mainMod = "ALT"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd(tema .. "iniciar")
end)

hl.config({
  general = {
    gaps_in = 0, gaps_out = 0, border_size = 2, layout = "dwindle",
    col = { active_border = 0xff8c2f4b, inactive_border = 0xff35151f },
  },
  decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
  animations = { enabled = false },
  misc = { background_color = 0xff15070d, disable_hyprland_logo = true, disable_splash_rendering = true, allow_session_lock_restore = true },
  input = {
    kb_layout = "br,us", kb_options = "grp:win_space_toggle", numlock_by_default = true,
    accel_profile = "flat", sensitivity = 0.1, follow_mouse = 1,
    touchpad = { natural_scroll = true },
  },
})

-- programas
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty --config-file=$HOME/.config/vinho/ghostty.conf"))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(tema .. "ipc launcher toggle"))
hl.bind("SUPER + A", hl.dsp.exec_cmd(tema .. "ipc launcher toggle"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(tema .. "ipc launcher power"))
hl.bind("SUPER + U", hl.dsp.exec_cmd(bloquear))
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | wl-copy]]))

-- janelas
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
for tecla, dir in pairs({ H = "left", L = "right", K = "up", J = "down" }) do
  hl.bind(mainMod .. " + " .. tecla, hl.dsp.focus({ direction = dir }))
  hl.bind(mainMod .. " + SHIFT + " .. tecla, hl.dsp.window.move({ direction = dir }))
end

-- workspaces
for i = 1, 10 do
  hl.bind(mainMod .. " + " .. i % 10, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mainMod .. " + SHIFT + " .. i % 10, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind(mainMod .. " + A", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind(mainMod .. " + minus", hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))

-- redimensionar (borda dourada enquanto ativo)
hl.bind(mainMod .. " + R", function()
  hl.config({ general = { col = { active_border = 0xffd9a862 } } })
  hl.dispatch(hl.dsp.submap("resize"))
end)
hl.define_submap("resize", function()
  hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
  hl.bind("escape", function()
    hl.config({ general = { col = { active_border = 0xff8c2f4b } } })
    hl.dispatch(hl.dsp.submap("reset"))
  end)
end)

-- brilho e volume
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
