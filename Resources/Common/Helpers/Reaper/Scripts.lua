-- @noindex

local function _getScriptHeaderValue(script_path, key)
    local content = OD_GetContent(script_path)
    for match in content:gmatch("%-%- @(.-)\n") do
        local val = match:match(key.." (.+)")
        if val then
            return val
        end
    end
end

function OD_GetScriptVersion(script_path)
    return _getScriptHeaderValue(script_path, 'version')
end

function OD_GetScriptDetails(script_name)
    local file = io.open(r.GetResourcePath() .. "/" .. "reaper-kb.ini")
    if not file then return "" end
    local content = file:read("*a")
    file:close()
    local santizedSn = script_name:gsub("([^%w])", "%%%1")
    if content:find(santizedSn) then
        local cmd_id, cmd_name, cmd_path = content:match('[^\r\n].+(RS.+) "Custom: (' .. santizedSn..'[^"]-)"%s"?([^"\r\n]+)')
        if cmd_path and not cmd_path:match("^/") then
            cmd_path = r.GetResourcePath() .. "/Scripts/" .. cmd_path
        end
        return cmd_id, cmd_name, cmd_path
    else
        r.ShowConsoleMsg('not found')
    end
end