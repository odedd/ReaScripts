-- @noindex
-- @description Pro tools style marker navigation
-- @author Oded Davidov
-- @version 1.0.0

r = reaper
local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]

local is_new_value, filename, sectionID, cmdID, mode, resolution, val, contextstr = r.get_action_context()
r.set_action_options(1)
local type, flag, keycode = string.match(contextstr, '(.-)%:(.-)%:(.-)$')
local markerCode = ''
local startTime = r.time_precise()
local lastKeyTime = startTime
local inactiveTime = 2
local keyStateCutoff = 0.05

if r.file_exists(p .. 'Resources/Helpers/Keyboard.lua') then
    dofile(p .. 'Resources/Common/Helpers/Keyboard.lua')
else
    dofile(p .. '../Resources/Common/Helpers/Keyboard.lua')
end

function PrintTraceback(err)
    local byLine = "([^\r\n]*)\r?\n?"
    local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
    local stack = {}
    for line in string.gmatch(err, byLine) do
        local str = string.match(line, trimPath) or line
        stack[#stack + 1] = str
    end
    r.ShowConsoleMsg(
        "Error: " .. stack[1] .. "\n\n" ..
        "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 3) .. "\n\n" ..
        "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
        "Platform:     \t" .. r.GetOS()
    )
end

-- function and concept by sexan
function PDefer(func)
    r.defer(function()
        local status, err = xpcall(func, debug.traceback)
        if not status then
            PrintTraceback(err)
            Release()
        end
    end)
end

function Exit()
    OD_ReleaseGlobalKeys()
end

r.atexit(Exit)

if type == 'key' and flag == 'V' then
    keycode = tonumber(keycode)
end

function capture()
    local time = r.time_precise()
    local timeFromLastKey = time - lastKeyTime
    local timeFromStart = time - startTime

    local key = OD_GetKeyPressed(OD_KEYCODES['0'], OD_KEYCODES['9'], true, 0)
    key = key or OD_GetKeyPressed(OD_KEYCODES.NUMPAD0, OD_KEYCODES.NUMPAD9, true, 0)

    if key then
        lastKeyTime = r.time_precise()
        markerCode = markerCode .. OD_KEYCODE_NAMES[key]:match('%d')
    end

    if timeFromLastKey > inactiveTime then return false end -- cancel if too much time passed since last key press
    if timeFromStart < keyStateCutoff then return true end  -- avoid capturing the key press used to launch the script
    if OD_IsGlobalKeyPressed(keycode, true, -keyStateCutoff) then
        local numMarkerCode = tonumber(markerCode) or -1
        if numMarkerCode == -1 then return false end
        r.GoToMarker(0, numMarkerCode, false)
    elseif OD_IsGlobalKeyPressed(OD_KEYCODES.ENTER, true, -keyStateCutoff) then
        local numMarkerCode = tonumber(markerCode) or -1
        if numMarkerCode == -1 then return false end
        -- if marker already exists at position, change its nunmber and edit it
        for i = 0, r.CountProjectMarkers(0) - 1 do
            local _, isrgn, pos, _, name, _, color = r.EnumProjectMarkers3(0, i)
            if isrgn == false and pos == r.GetCursorPosition() then
                r.SetProjectMarkerByIndex(0, i, false, pos, 0, numMarkerCode, name,color)
                r.Main_OnCommand(40614, 0)
                return false
            end
        end
        local idx = reaper.AddProjectMarker(0, false, r.GetCursorPosition(), 0, '', numMarkerCode)
        r.Main_OnCommand(40614, 0)
    else
        return true
    end
end

function main()
    if capture() then r.defer(main) end
end

PDefer(main)