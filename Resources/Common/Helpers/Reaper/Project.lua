-- @noindex

function OD_GetProjectPaths()
    local projectRecordingPath = r.GetProjectPath():gsub('\\', '/')
    local proj, fullProjPath = r.EnumProjects(-1, '')           -- full project name including path and RPP file
    fullProjPath = fullProjPath:gsub('\\', '/')
    local projFileName = r.GetProjectName(proj)                 -- just the RPP file
    local projPath = fullProjPath:gsub(OD_EscapePattern(projFileName) .. '$', '') -- just the project path
    local relProjectRecordingPath = OD_GetRelativeOrAbsoluteFile(projectRecordingPath, projPath)
    if relProjectRecordingPath == projectRecordingPath then relProjectRecordingPath = '' end
    return projPath, projFileName, fullProjPath, projectRecordingPath, relProjectRecordingPath
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

function OD_GetProjGUID()
    local ret, proj_guid = reaper.GetProjExtState(0, "OD_Scripts", "proj_guid")

    if ret == 1 then
        return proj_guid
    else
        proj_guid = reaper.genGuid("")
        reaper.SetProjExtState(0, "OD_Scripts", "proj_guid", proj_guid, true)
        return proj_guid
    end
end

-- a function by binbinhfr:
-- https://forum.cockos.com/showpost.php?p=2610343&postcount=5
local proj_guid_last = ""
function OD_DidProjectGUIDChange()
    local changed = false
    local proj_guid = OD_GetProjGUID()

    if OD_GetProjGUID() ~= proj_guid_last then
        changed = true
    end

    proj_guid_last = proj_guid
    return changed
end
