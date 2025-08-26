-- @noindex
function OD_GetScreenSize()
    local left, top, right, bottom = reaper.JS_Window_GetViewportFromRect(0, 0, 0, 0, false)
    if _OD_ISMAC then
        local oldTop = top
        top = bottom
        bottom = oldTop
    end
    return right, bottom
end

function OD_GetMousePos()
    local x, y = reaper.GetMousePosition()
    if _OD_ISMAC then
        local _, bottom = OD_GetScreenSize()
        y = bottom - y
    end
    return x, y
end
