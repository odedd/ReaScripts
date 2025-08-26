-- @noindex

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]

dofile(p .. 'Init.lua')
dofile(p .. 'Helpers.lua')
dofile(p .. 'ReaperHelpers.lua')
dofile(p .. 'AppHelpers.lua')

r = reaper
Scr = {}
OS_is = nil

local function matchUrlInString(str)
    local preString, url = string.match(str, "(.-)(https?://[%w-_%.%?%.:/%+=&]+)")
    return url, OD_Trim(preString or '')
end
function OD_FindContentKey(content, key, self)
    if self then
        for match in content:gmatch("%-%- @(.-)\n") do
            local key, val = match:match("(.-) (.+)")
            if val then
                local url, description = matchUrlInString(val)
                if url and description ~= '' then
                    Scr[key:lower()] = Scr[key:lower()] or {}
                    -- val = {[description] = url}
                    Scr[key:lower()][description] = url
                else
                    Scr[key:lower()] = val
                end
                -- if Scr[key:lower()] then
                -- if type(Scr[key:lower()]) ~= 'table' then
                -- Scr[key:lower()] = { Scr[key:lower()] }
                -- end
                -- table.insert(Scr[key:lower()], val)
                -- else
                -- end
            end
        end
        return
    else
        content = content:match(key .. "[:=].-\n")
    end
    return content and content:gsub(key .. "[:=]%s?", "") or false
end

local function OD_GetScr()
    Scr.path, Scr.secID, Scr.cmdID = select(2, r.get_action_context())
    Scr.dir = Scr.path:match(".+[\\/]")
    Scr.basename = Scr.path:match("^.+[\\/](.+)$")
    Scr.no_ext = Scr.basename:match("(.+)%.")
    OD_FindContentKey(OD_GetContent(Scr.path), "", true)
    Scr.version = Scr.version or "0.0.0"
    Scr.major_version = OD_GetMajorVersion(Scr.version)
    Scr.minor_version = OD_GetMinorVersion(Scr.version)
    Scr.dfsetfile = Scr.dir .. Scr.no_ext .. '.ini'
    Scr.namespace = "Odedd"
    Scr.name = Scr.description
    Scr.developer = Scr.author
    Scr.context_name = Scr.namespace .. ' ' .. Scr.name
    Scr.ext_name = Scr.namespace:gsub(' ', '_') .. '_' .. Scr.name:gsub(' ', '_')
    r.ver = tonumber(r.GetAppVersion():match("[%d%.]+"))
end

local function OD_GetOS()
    local cur_os = reaper.GetOS()
    OS_is = {
        win = cur_os:lower():match("win") and true or false,
        mac = cur_os:lower():match("osx") or cur_os:lower():match("macos") and true or false,
        mac_arm = cur_os:lower():match("macos") and true or false,
        lin = cur_os:lower():match("other") and true or false
    }
end

local function prereqCheck(args)
    args = args or {}
    args.scripts = args.scripts or
    {}                                -- {"cfillion_Apply render preset.lua" , "r.GetResourcePath() .. '/Scripts/ReaTeam Scripts/Rendering/cfillion_Apply render preset.lua'"}
    local errors = {}
    local reapackFilter = nil
    
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
                reapackFilter = (reapackFilter and (reapackFilter .. ' OR ') or '') ..
                '"js_ReaScriptAPI: API functions for ReaScripts"'
            end
        else
            table.insert(errors,
                'This script requires the JS_ReaScriptAPI extension.\nPlease install it via ReaPack.')
            reapackFilter = (reapackFilter and (reapackFilter .. ' OR ') or '') ..
            '"js_ReaScriptAPI: API functions for ReaScripts"'
        end
    end

    if check_reimgui then
        if OD_FileExists(reaimgui_script_path) then
            local verCheck = loadfile(reaimgui_script_path)
            local status, err = pcall(verCheck(), reaimgui_version)
            if not status then
                table.insert(errors, ('ReaImgui version must be %s or above.\nPlease update via ReaPack.'):format(
                    reaimgui_version))
                reapackFilter = (reapackFilter and (reapackFilter .. ' OR ') or '') ..
                '"ReaImGui: ReaScript binding for Dear ImGui"'
            elseif not r.ImGui_ColorConvertU32ToDouble4 then
                table.insert(errors,
                    "ReaImGui error.\nPlease reinstall it via ReaPack.\n\nIf you already installed it, remember to restart reaper.")
                reapackFilter = (reapackFilter and (reapackFilter .. ' OR ') or '') ..
                '"ReaImGui: ReaScript binding for Dear ImGui"'
            end
        else
            table.insert(errors, 'This script requires ReaImgui.\nPlease install it via ReaPack.')
            reapackFilter = (reapackFilter and (reapackFilter .. ' OR ') or '').. '"ReaImGui: ReaScript binding for Dear ImGui"'
        end
    end
    return errors, reapackFilter
end

local function OD_GetReaperInfo()
    r.x64 = reaper.GetAppVersion():match(".*(64)") and true or nil
    r.path = reaper.GetResourcePath():gsub("\\", "/")
    r.ini = OD_GetContent(reaper.get_ini_file():gsub("\\", "/"))
end

-------------------------------------------
-- Public Stuff
-------------------------------------------

function OD_Init()
    OD_GetReaperInfo()
    OD_GetScr()
    OD_GetOS()
end

function OD_PrereqsOK(args)
    local errors, reapackFilter = prereqCheck(args)
    if #errors > 0 then
        r.MB(table.concat(errors, '\n------------\n'), Scr.name, 0)
        if reapackFilter and reaper.ReaPack_BrowsePackages then
            reaper.ReaPack_BrowsePackages(reapackFilter)
        end
    end

    return (next(errors) == nil)
end
