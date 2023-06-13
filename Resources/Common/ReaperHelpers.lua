-- @noindex
function OD_GetProjectPaths()
    local projectRecordingPath = r.GetProjectPath()
    local proj, fullProjPath = r.EnumProjects(-1, '') -- full project name including path and RPP file
    local projFileName = r.GetProjectName(proj) -- just the RPP file
    local projPath = fullProjPath:gsub(projFileName .. '$', '') -- just the project path
    local relProjectRecordingPath = OD_GetRelativeOrAbsolutePath(projectRecordingPath,projPath)
    return projPath, projFileName, fullProjPath, projectRecordingPath, relProjectRecordingPath
end

function OD_GetReaperActionCommandId(actionNumber)
    local actionId = r.ReverseNamedCommandLookup(actionNumber)
    if actionId == nil then
        return actionNumber
    else
        return '_' .. actionId
    end
end

function OD_GetReaperActionNameOrCommandId(actionNamedCommandID)
    actionNamedCommandID = (type(actionNamedCommandID) == 'string') and '_' .. actionNamedCommandID or
                               actionNamedCommandID
    local actionNumber = r.NamedCommandLookup(actionNamedCommandID)
    if r.APIExists('CF_GetCommandText') then -- if SWS, return name
        return true, r.CF_GetCommandText(0, actionNumber)
    else -- otherwise Fallback to Action ID
        return false, OD_GetReaperActionCommandId(actionNumber)
    end
end

local function deleteLongerProjExtState(section, key)
    local n = '*'
    while r.GetProjExtState(0, section, key .. n) == 1 do
        r.SetProjExtState(0, section, key .. n, '')
        n = n .. '*'
    end
end

function OD_SaveLongProjExtState(section, key, val)
    local maxLength = 2 ^ 12 - #key - 2
    deleteLongerProjExtState(section, key)
    r.SetProjExtState(0, section, key, val:sub(1, maxLength))
    if #val > maxLength then
        OD_SaveLongProjExtState(section, key .. '*', val:sub(maxLength + 1, #val))
    end
end

function OD_LoadLongProjExtKey(section, key)
    local i = 0
    local maxLength = 2 ^ 12 - #key - 2
    while true do
        local retval, k, val = r.EnumProjExtState(0, section, i)
        if not retval then
            break
        end
        if (k == key) then
            if #val == maxLength then
                val = val .. (OD_LoadLongProjExtKey(section, key .. '*') or '')
            end
            return val
        end
        i = i + 1
    end
end
