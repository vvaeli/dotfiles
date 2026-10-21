-- Start Wayland clients after the compositor has initialized its display.
local function startSession()
    hl.exec_cmd("/usr/bin/bash @HOME@/.config/hypr/scripts/session-start")
end
hl.on("hyprland.start", startSession)
hl.on("config.reloaded", startSession)
