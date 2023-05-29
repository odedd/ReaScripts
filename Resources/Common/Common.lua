local frameCount = 0

function getContent(path)
    local file = io.open(path)
    if not file then
        return ""
    end
    local content = file:read("*a")
    file:close()
    return content
end

function findContentKey(content, key, self)
    if self then
        for match in content:gmatch("%-%- @(.-)\n") do
            local key, val = match:match("(.-) (.+)")
            if val then
                scr[key:lower()] = val
            end
        end
        return
    else
        content = content:match(key .. "[:=].-\n")
    end
    return content and content:gsub(key .. "[:=]%s?", "") or false
end

scr = {}
scr.path, scr.secID, scr.cmdID = select(2, r.get_action_context())
scr.dir = scr.path:match(".+[\\/]")
scr.basename = scr.path:match("^.+[\\/](.+)$")
scr.no_ext = scr.basename:match("(.+)%.")
findContentKey(getContent(scr.path), "", true)
scr.namespace = "Odedd"
scr.name = scr.description
scr.context_name = scr.namespace:gsub(' ', '_') .. '_' .. scr.name:gsub(' ', '_')
r.ver = tonumber(r.GetAppVersion():match("[%d%.]+"))

-------------------
-- basic helpers --
-------------------

string.split = function(s, delimiter)
    result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function prereqCheck(args)

    args = args or {}
    args.scripts = args.scripts or {} -- {"cfillion_Apply render preset.lua" , "r.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua'"}
    local errors = {}

    local reaimgui_script_path = args.reaimgui_path or r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
    local check_reimgui = args.reaimgui or (args.reaimgui_version ~= nil) or false
    local check_sws = args.sws

    local reaimgui_version = args.reaimgui_version or '0.7' 
    local min_reaper_version = args.reaper_version or 6.44 

    if r.ver < min_reaper_version then
        table.insert(errors, 'This script is designed to work with REAPER v' .. min_reaper_version .. '+')
    end

    for desc,file in pairs(args.scripts) do
        reaper.ShowConsoleMsg('hi')
        if file_exists(file) then
            applyPresetScript = loadfile(file)
        else
            table.insert(errors, 'This script requires "'..desc..'".\nPlease install it via ReaPack.')
        end
    end

    if check_sws then
        if r.APIExists('CF_GetCommandText') then 
            table.insert(errors, 'This script requires the SWS/S&M extension.\nPlease download and install it at\nhttps://www.sws-extension.org/.')
        end
    end

    if check_reimgui then
        if file_exists(reaimgui_script_path) then
            local verCheck = loadfile(reaimgui_script_path)
            local status, err = pcall(verCheck(), reaimgui_version)
            if not status then
                table.insert(errors,
                    ('ReaImgui version must be %s or above.\nPlease update via ReaPack.'):format(reaimgui_version))
            elseif not r.ImGui_ColorConvertU32ToDouble4 then
                table.insert(errors,
                    "ReaImGui error.\nPlease reinstall it via ReaPack.\n\nIf you already installed it, remember to restart reaper.")
            end
        else
            table.insert(errors, 'This script requires ReaImgui.\nPlease install it via ReaPack.')
        end
    end
    return errors
end

function checkPrerequisites(args)
    local errors = prereqCheck(args)
    if #errors > 0 then
        r.MB(table.concat(errors, '\n------------\n'), scr.name, 0)
    end

    return (next(errors) == nil)
end