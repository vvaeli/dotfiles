local programs = ...
local terminal, fileManager, menu = programs.terminal, programs.fileManager, programs.menu

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Показать / скрыть панель Quickshell на всех мониторах.
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call bar toggle"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call crosshair toggle"))
-- Esc закрывает меню панели, где бы ни был курсор; программы тоже получают клавишу.
hl.bind("Escape", hl.dsp.global("md3:menuClose"), { non_consuming = true })

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call clipboard toggle"))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call launcher toggle"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call launcher toggle"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call launcher toggle"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("env QT_QPA_PLATFORMTHEME= qs -c md3 ipc call wallpaper toggle"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/lock"))
-- Screenshots in the ShareX style: the shell freezes every monitor with drawing toolbars.
local md3Shot = "@HOME@/.config/quickshell/md3/screenshot.py"
hl.bind("Print", hl.dsp.exec_cmd("qs -c md3 ipc call screenshot region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("qs -c md3 ipc call screenshot regionEdit"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("python3 " .. md3Shot .. " screen"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("python3 " .. md3Shot .. " active"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/system-control volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/system-control volume-down"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.config/hypr/scripts/system-control volume-mute"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.config/hypr/scripts/system-control mic-mute"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("~/.config/hypr/scripts/system-control brightness-up"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("~/.config/hypr/scripts/system-control brightness-down"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Requires playerctl


