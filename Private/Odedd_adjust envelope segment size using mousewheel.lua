-- @noindex

local r = reaper
r.set_action_options(8)

r.ClearConsole()
function loop()
    local window, segment, details = r.BR_GetMouseCursorContext()
    local env, istakeEnvelope = r.BR_GetMouseCursorContext_Envelope()
    if details == 'env_segment' or env then
        r.ShowConsoleMsg('env_segment\n')
    end
    local char = gfx.getchar()
	-- gfx.update()
    if char == 27 or char == -1 then
        r.ShowConsoleMsg('exiting\n')
        return
    else
        r.defer(loop)
    end
end
local name, x, y, w, h = "text demo", 200, 200, 200, 200
gfx.init(name, 0, 0, 0, 0, 0)
r.ShowConsoleMsg('starting...\n')
r.defer(loop)
