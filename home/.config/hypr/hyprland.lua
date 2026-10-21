-- Конфигурация Hyprland. Настройки находятся в conf/.
-- loadfile выполняет модули заново при каждой перезагрузке конфига.
local configDir = assert(debug.getinfo(1, "S").source:match("^@(.*/)"),
    "Не удалось определить каталог конфигурации Hyprland")

local function loadConfig(name, ...)
    local chunk = assert(loadfile(configDir .. "conf/" .. name .. ".lua"))
    return chunk(...)
end

loadConfig("monitors")
local programs = loadConfig("programs")
loadConfig("autostart", programs)
loadConfig("environment")
loadConfig("permissions")
loadConfig("appearance")
-- Цвета из обоев (пишет matugen). Пока файла нет, остаются цвета из appearance.lua.
local wallpaperColors = loadfile(configDir .. "conf/colors.lua")
if wallpaperColors then wallpaperColors() end
loadConfig("animations")
loadConfig("layouts")
loadConfig("misc")
loadConfig("input")
loadConfig("keybindings", programs)
loadConfig("rules")

-- deadlocked_overlay no_blur windowrule
hl.window_rule({
    match = {
        title = "^(deadlocked_overlay)$",
    },
    no_blur = true,
})
