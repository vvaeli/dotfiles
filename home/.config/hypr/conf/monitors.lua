------------------
---- MONITORS ----
------------------

-- Любой подключённый монитор: родное разрешение, автоматическое расположение и масштаб.
-- Свою раскладку можно описать отдельными hl.monitor({ output = "DP-1", ... }), как в
-- https://wiki.hypr.land/Configuring/Basics/Monitors/ ; список выходов: hyprctl monitors.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
