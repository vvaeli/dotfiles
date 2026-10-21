-- Плавные анимации без пружинного отскока.
-- speed задаёт длительность в десятых долях секунды.
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("md3Decelerate", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.curve("md3Standard",   { type = "bezier", points = { {0.4, 0}, {0.2, 1} } })
hl.curve("md3Exit",       { type = "bezier", points = { {0.4, 0}, {1, 1} } })

hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "md3Decelerate" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "md3Standard" })
hl.animation({ leaf = "windows", enabled = true, speed = 3.5, bezier = "md3Decelerate" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "md3Decelerate", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "md3Exit", style = "popin 97%" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "md3Standard" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "md3Decelerate" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.5, bezier = "md3Exit" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "md3Decelerate" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "md3Decelerate", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "md3Exit", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 3, bezier = "md3Decelerate" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "md3Exit" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "md3Standard", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 4, bezier = "md3Standard", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4, bezier = "md3Standard", style = "slide" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "md3Decelerate" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })


-- Плавная смена силы тени при переключении фокуса (300 мс).
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 3, bezier = "md3Standard" })
