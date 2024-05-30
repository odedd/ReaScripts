-- @noindex
_OD_ISMAC = reaper.GetOS():lower():match("osx") or reaper.GetOS():lower():match("macos")
function OD_GetScreenSize()
    local left, top, right, bottom = reaper.JS_Window_GetViewportFromRect(0, 0, 0, 0, false)
    if _OD_ISMAC then
        local oldTop = top
        top = bottom
        bottom = oldTop
    end
    return left, top, right, bottom
end

function OD_GetMousePos()
    local x, y = reaper.GetMousePosition()
    if _OD_ISMAC then
        local _, _, _, bottom = OD_GetScreenSize()
        y = bottom - y
    end
    return x, y
end
