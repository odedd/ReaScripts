-- @noindex

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
dofile(p .. 'Helpers.lua')
dofile(p .. 'ReaperHelpers.lua')

r = reaper
local scr = {}

local function OD_FindContentKey(content, key, self)
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

local function OD_GetScr()
    scr.path, scr.secID, scr.cmdID = select(2, r.get_action_context())
    scr.dir = scr.path:match(".+[\\/]")
    scr.basename = scr.path:match("^.+[\\/](.+)$")
    scr.no_ext = scr.basename:match("(.+)%.")
    OD_FindContentKey(OD_GetContent(scr.path), "", true)
    scr.dfsetfile = scr.dir..scr.no_ext..'.ini'
    scr.namespace = "Odedd"
    scr.name = scr.description
    scr.context_name = scr.namespace:gsub(' ', '_') .. '_' .. scr.name:gsub(' ', '_')
    r.ver = tonumber(r.GetAppVersion():match("[%d%.]+"))
    return scr
end

local function OD_GetOS()
    local cur_os = reaper.GetOS()
    local os_is = {
        win = cur_os:lower():match("win") and true or false,
        mac = cur_os:lower():match("osx") or cur_os:lower():match("macos") and true or false,
        mac_arm = cur_os:lower():match("macos") and true or false,
        lin = cur_os:lower():match("other") and true or false
    }
    return os_is
end

local function prereqCheck(args)

    args = args or {}
    args.scripts = args.scripts or {} -- {"cfillion_Apply render preset.lua" , "r.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua'"}
    local errors = {}

    local reaimgui_script_path = args.reaimgui_path or r.GetResourcePath() ..
                                     '/Scripts/ReaTeam Extensions/API/imgui.lua'
    local check_reimgui = args.reaimgui or (args.reaimgui_version ~= nil) or false
    local reaimgui_version = args.reaimgui_version or '0.7'
    
    local check_sws = args.sws

    local check_js = args.js or (args.js_version ~= nil) or false
    local js_version = args.js_version

    local min_reaper_version = args.reaper_version or 6.44

    if r.ver < min_reaper_version then
        table.insert(errors, 'This script is designed to work with REAPER v' .. min_reaper_version .. '+')
    end

    for desc, file in pairs(args.scripts) do
        if not OD_FileExists(file) then
            table.insert(errors, 'This script requires "' .. desc .. '".\nPlease install it via ReaPack.')
        end
    end

    if check_sws then
        if not r.APIExists('CF_GetCommandText') then
            table.insert(errors,
                'This script requires the SWS/S&M extension.\nPlease download and install it at\nhttps://www.sws-extension.org/.')
        end
    end

    if check_js then
        if r.APIExists('JS_ReaScriptAPI_Version') then
            if r.JS_ReaScriptAPI_Version() < js_version then
                table.insert(errors, ('JS_ReaScriptAPI version must be %s or above.\nPlease update via ReaPack.'):format(
                    js_version))
            end
        else
            table.insert(errors,
                'This script requires the JS_ReaScriptAPI extension.\nPlease install it via ReaPack.')
        end
    end

    if check_reimgui then
        if OD_FileExists(reaimgui_script_path) then
            local verCheck = loadfile(reaimgui_script_path)
            local status, err = pcall(verCheck(), reaimgui_version)
            if not status then
                table.insert(errors, ('ReaImgui version must be %s or above.\nPlease update via ReaPack.'):format(
                    reaimgui_version))
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


-------------------------------------------
-- Public Stuff
-------------------------------------------

function OD_Init()
    return OD_GetScr(), OD_GetOS()
end

function OD_PrereqsOK(args)
    local errors = prereqCheck(args)
    if #errors > 0 then
        r.MB(table.concat(errors, '\n------------\n'), scr.name, 0)
    end

    return (next(errors) == nil)
end
