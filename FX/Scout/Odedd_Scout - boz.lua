-- This file was created by Scout on Wed Jul 23 14:26:27 2025

local r = reaper
local context = 'Odedd_Scout'
local script_name = 'Odedd_Scout.lua'
local cmd = 'APPLY_FILTER '..
[[{{
["fxCategory"]="Guitar",
["text"]="",
["tags"]={2},
},
{
[65]=true,
},
}
]]..''

function getScriptId(script_name)
    local file = io.open(r.GetResourcePath().."/".."reaper-kb.ini")
    if not file then return "" end
    local content = file:read("*a")
    file:close()
    local santizedSn = script_name:gsub("([^%w])", "%%%1")
    if content:find(santizedSn) then
        return content:match('[^\r\n].+(RS.+) "Custom: '..santizedSn)
    end
end

local cmdId = getScriptId(script_name)

if cmdId then
    if r.GetExtState(context, 'defer') ~= '1' then
        local intId = r.NamedCommandLookup('_'..cmdId)
        if intId ~= 0 then r.Main_OnCommand(intId,0) end
    end
    r.SetExtState(context, 'EXTERNAL_COMMAND',cmd, false)
else
    r.MB(script_name..' not installed', script_name,0)
end