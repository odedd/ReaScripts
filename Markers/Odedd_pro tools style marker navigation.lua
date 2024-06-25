-- @description Pro tools style marker navigation
-- @author Oded Davidov
-- @version 1.0.3
-- @donation https://paypal.me/odedda
-- @license GNU GPL v3
-- @about
--   # Pro tools style marker navigation
--   usage:
--      1.  assign a keyboard shortcut to this script
--      2.  press the shortcut key
--      3.  press keys to indicate the marker number you want to navigate to or create
--      4.  press the shortcut key again to navigate to the next marker with the same number
--          if the previous modifier key is held (default: SHIFT), the script will navigate to the previous marker with the same number
--      5.  alternatively, press ENTER to create a marker at the current position
--          if the region modifier key is held (default: SHIFT), a region will be created instead of a marker
--          if a marker or region already exists at the same position, its number will be changed and the edit window will open
--
--   look at the settings section to customize the script behavior
--
--   This script is free, but as always, donations are most welcome at https://paypal.me/odedda :)
-- @provides
--   [nomain] ../Resources/Common/* > Resources/Common/
--   [nomain] ../Resources/Common/Helpers/* > Resources/Common/Helpers/
--   [nomain] ../Resources/Common/Helpers/App/* > Resources/Common/Helpers/App/
--   [nomain] ../Resources/Common/Helpers/Reaper/* > Resources/Common/Helpers/Reaper/
--   [nomain] ../Resources/Fonts/* > Resources/Fonts/
--   [nomain] ../Resources/Icons/* > Resources/Icons/
-- @changelog
--   Number keys pressed before script is launched are no longer captured

r = reaper
local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]

if r.file_exists(p .. 'Resources/Common/Common.lua') then
    dofile(p .. 'Resources/Common/Common.lua')
else
    dofile(p .. '../Resources/Common/Common.lua')
end

---------------------------------
-------- USER SETTINGS ----------
---------------------------------

-- time in seconds to wait for the next key press before cancelling the capture
local inactiveTime = 1
-- if true, the added marker will be edited after creation by default, can be toggled with the editModifier key (default: ALT)
local editAfterAdding = false
-- if true, the play cursor will be used instead of the edit cursor when playing
local usePlayCursorPositionWhenPlaying = true
-- if true, the makrer/region positions will snap to the grid if snapping is enabled
local snapToGrid = false
-- to snap even when snapping in Reaper is off, set this to true
local snapEvenWhenNotEnabled = false


-- Navigation Modifiers*
-- when this key is held with combination of the script key, the script will go to the previous marker/region of the same number
local prevModifier = OD_KEYCODES.SHIFT

-- ENTER Key Modifiers*
-- if this key is held when pressing ENTER, a region will be created instead of a marker
local regionModifier = OD_KEYCODES.SHIFT
-- if this key is held when pressing ENTER, the default editAfterAdding behavior will be toggled.
local editModifier = OD_KEYCODES.ALT

--* Possible modifiers: OD_KEYCODES.CTRL (control on pc / cmd on osx), OD_KEYCODES.STARTKEY (control on a mac), OD_KEYCODES.ALT (alt on pc / opt on osx), OD_KEYCODES.SHIFT

---------------------------------
-------- END OF SETTINGS --------
---------------------------------

OD_Init()

if OD_PrereqsOK({
        js_version = 1.310,    -- required for JS_VKeys_GetState
        reaper_version = 7.03, -- required for set_action_options
    }) then
    r.set_action_options(1)
    local _, _, _, _, _, _, _, contextstr = r.get_action_context()
    local contextType, contextFlag, contextKeycode = string.match(contextstr, '(.-)%:(.-)%:(.-)$')
    local markerCode = ''
    local startTime = r.time_precise()
    local lastKeyTime = startTime
    local keyStateCutoff = 0.05
    local debugMode = false

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

    -- functions by sexan
    local function release()
        OD_ReleaseGlobalKeys()
    end
    local function exit()
        if debugMode then
            r.ShowConsoleMsg('-----------------------------------\n')
            r.ShowConsoleMsg('Exiting...\n')
            r.ShowConsoleMsg('markerCode: ' .. tostring(markerCode) .. '\n')
            r.ShowConsoleMsg('-----------------------------------\n')
        end
        release()
    end
    local function PDefer(func)
        r.defer(function()
            local status, err = xpcall(func, debug.traceback)
            if not status then
                PrintTraceback(err)
                release()
            end
        end)
    end

    r.atexit(exit)

    local function snapIfNeeded(pos)
        if snapToGrid then
            local snapOn = r.GetToggleCommandState(1157) == 1 -- Options: Toggle snapping
            if snapEvenWhenNotEnabled and not snapOn then
                r.Main_OnCommand(1157, 0)
            end
            pos = r.SnapToGrid(0, pos)
            if snapEvenWhenNotEnabled and not snapOn then r.Main_OnCommand(1157, 0) end
        end
        return pos
    end

    local function getRelevantPos()
        local playing = r.GetPlayState() & 1 == 1 or r.GetPlayState() & 4 == 4
        local cursorPos = (usePlayCursorPositionWhenPlaying and playing) and r.GetPlayPosition() or
            r.GetCursorPosition()
        cursorPos = snapIfNeeded(cursorPos)
        return cursorPos
    end

    local function getRegionBounds(cursorPos)
        local start, finish = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
        -- no time selection, create a region from latest marker / the end of the latest region / project start to the cursor
        if start == finish then
            start = 0
            for i = 0, r.CountProjectMarkers(0) - 1 do
                local _, isrgn, pos, rgnend, _, idx, _ = r.EnumProjectMarkers3(0, i)
                local pos = isrgn and rgnend or pos
                start = cursorPos > pos and pos or start
            end
            finish = cursorPos
        end
        start = snapIfNeeded(start)
        finish = snapIfNeeded(finish)
        return start, finish
    end

    local function seekMarkerOrRegion(numMarkerCode, forward)
        local cursorPos = getRelevantPos()
        local foundPos
        local firstPos
        local lastPos
        for i = 0, r.CountProjectMarkers(0) - 1 do
            if (forward and not foundPos) or (not forward) then
                local _, _, pos, _, _, idx, _ = r.EnumProjectMarkers3(0, i)
                if idx == numMarkerCode then
                    firstPos = firstPos or pos
                    lastPos = pos
                    if forward then
                        if pos > cursorPos then
                            foundPos = pos
                        end
                    else
                        if pos < cursorPos then
                            foundPos = pos
                        end
                    end
                end
            end
        end
        foundPos = foundPos or (forward and firstPos or lastPos)
        if foundPos then
            r.SetEditCurPos(foundPos, true, true)
        end
    end

    local function createOrEditMarkerOrRegion(numMarkerCode, createRegion, toggleEditingBehavior)
        local cursorPos = getRelevantPos()
        local start, finish = getRegionBounds(cursorPos)
        -- if marker already exists at position, or region already exists in those bounds, change its nunmber and edit it
        for i = 0, r.CountProjectMarkers(0) - 1 do
            local _, isrgn, pos, rgnend, name, idx, color = r.EnumProjectMarkers3(0, i)
            if (createRegion and isrgn and start == pos and finish == rgnend) or (createRegion == false and isrgn == false and pos == cursorPos) then
                r.SetProjectMarkerByIndex(0, i, isrgn, pos, rgnend, numMarkerCode, name, color)
                if createRegion then r.SetEditCurPos(start, false, false) end
                r.Main_OnCommand(createRegion and 40616 or 40614, 0)
                if createRegion then r.SetEditCurPos(cursorPos, false, false) end
                return false
            elseif createRegion and idx == numMarkerCode and isrgn == true then -- if creating a region and a region with the same number already exists, display message
                r.ShowMessageBox('Region with the same number already exists', Scr.name, 0)
                return false
            end
        end

        if createRegion then
            r.AddProjectMarker(0, true, start, finish, '', numMarkerCode)
            if (editAfterAdding and not toggleEditingBehavior) or (editAfterAdding == false and toggleEditingBehavior) then
                r.SetEditCurPos(start, false, false)
                r.Main_OnCommand(40616, 0)
                r.SetEditCurPos(cursorPos, false, false)
            end
        else
            r.AddProjectMarker(0, false, cursorPos, 0, '', numMarkerCode)
            if (editAfterAdding and not toggleEditingBehavior) or (editAfterAdding == false and toggleEditingBehavior) then
                r.SetEditCurPos(cursorPos, false, false)
                r.Main_OnCommand(40614, 0)
            end
        end
    end

    local function capture()
        local time = r.time_precise()
        local timeFromLastKey = time - lastKeyTime
        local timeFromStart = time - startTime

        local key = OD_GetKeyPressed(OD_KEYCODES['0'], OD_KEYCODES['9'], true, -timeFromStart)
        key = key or OD_GetKeyPressed(OD_KEYCODES.NUMPAD0, OD_KEYCODES.NUMPAD9, true, -timeFromStart)

        if key then
            if debugMode then
                r.ShowConsoleMsg('key: ' .. OD_KEYCODE_NAMES[key] .. '\n')
            end
            lastKeyTime = r.time_precise()
            markerCode = markerCode .. OD_KEYCODE_NAMES[key]:match('%d')
        end

        if timeFromLastKey > inactiveTime then return false end -- cancel if too much time passed since last key press
        if timeFromStart < keyStateCutoff then return true end  -- avoid capturing the key press used to launch the script
        if OD_IsGlobalKeyPressed(contextKeycode, true, -keyStateCutoff) then
            if debugMode then
                r.ShowConsoleMsg('Pressed contextKeycode\n')
            end
            local numMarkerCode = tonumber(markerCode) or -1
            if numMarkerCode == -1 then return false end
            local forward = not OD_IsGlobalKeyDown(prevModifier, false, -timeFromStart)
            seekMarkerOrRegion(numMarkerCode, forward)
        elseif OD_IsGlobalKeyPressed(OD_KEYCODES.ENTER, true, -keyStateCutoff) then
            local numMarkerCode = tonumber(markerCode) or -1
            if numMarkerCode == -1 then return false end
            local createRegion = OD_IsGlobalKeyDown(regionModifier, false, -timeFromStart)
            local toggleEditingBehavior = OD_IsGlobalKeyDown(editModifier, false, -timeFromStart)
            if debugMode then
                r.ShowConsoleMsg('Pressed Enter\n')
                r.ShowConsoleMsg('createRegion: ' .. tostring(createRegion) .. '\n')
                r.ShowConsoleMsg('toggleEditingBehavior: ' .. tostring(toggleEditingBehavior) .. '\n')
            end
            createOrEditMarkerOrRegion(numMarkerCode, createRegion, toggleEditingBehavior)
        else
            return true
        end
    end

    local function main()
        if capture() then PDefer(main) end
    end

    if debugMode then
        r.ClearConsole()
        r.ShowConsoleMsg('-----------------------------------\n')
        r.ShowConsoleMsg('os: ' .. r.GetOS() .. '\n')
        r.ShowConsoleMsg('-----------------------------------\n')
        r.ShowConsoleMsg('contextType: ' .. contextType .. '\n')
        r.ShowConsoleMsg('contextFlag: ' .. contextFlag .. '\n')
        r.ShowConsoleMsg('contextKeycode: ' .. contextKeycode .. '\n')
        r.ShowConsoleMsg('-----------------------------------\n')
        r.ShowConsoleMsg('inactiveTime: ' .. inactiveTime .. '\n')
        r.ShowConsoleMsg('editAfterAdding: ' .. tostring(editAfterAdding) .. '\n')
        r.ShowConsoleMsg('usePlayCursorPositionWhenPlaying: ' .. tostring(usePlayCursorPositionWhenPlaying) .. '\n')
        r.ShowConsoleMsg('snapToGrid: ' .. tostring(snapToGrid) .. '\n')
        r.ShowConsoleMsg('snapEvenWhenNotEnabled: ' .. tostring(snapEvenWhenNotEnabled) .. '\n')
        r.ShowConsoleMsg('prevModifier: ' .. OD_KEYCODE_NAMES[prevModifier] .. '\n')
        r.ShowConsoleMsg('regionModifier: ' .. OD_KEYCODE_NAMES[regionModifier] .. '\n')
        r.ShowConsoleMsg('editModifier: ' .. OD_KEYCODE_NAMES[editModifier] .. '\n')
        r.ShowConsoleMsg('-----------------------------------\n')
    end
    if contextType == 'key' and contextFlag == 'V' then
        contextKeycode = tonumber(contextKeycode)
        PDefer(main)
    else
        r.ShowMessageBox('This script must be run from the action list using a keyboard shortcut with no modifiers',
            Scr.name, 0)
    end
end