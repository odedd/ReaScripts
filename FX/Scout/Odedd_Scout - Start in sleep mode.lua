-- @noindex
-- This is meant to be used as a startup action, to allow scout to 
-- load assets when Reaper starts and thereby reduce loading time 
-- on the first launch
local r = reaper

local function getScriptId()
    local file = io.open(r.GetResourcePath().."/".."reaper-kb.ini")
    if not file then return "" end
    local content = file:read("*a")
    file:close()
    local santizedSn = ('Odedd_Scout.lua'):gsub("([^%w])", "%%%1")
    if content:find(santizedSn) then
        return content:match('[^\r\n].+(RS.+) "Custom: '..santizedSn)
    end
end

local cmdId = getScriptId()

if cmdId then
    local intId = r.NamedCommandLookup('_'..cmdId)
    if intId ~= 0 then r.Main_OnCommand(intId,0) end
    r.SetExtState('Odedd_Scout', 'EXTERNAL_COMMAND','START_AND_SLEEP', false)
else
    r.MB('Scout not installed', 'Scout',0)
end