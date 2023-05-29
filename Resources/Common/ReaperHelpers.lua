-- @noindex

function getReaperActionCommandId(actionNumber)
    local actionId = r.ReverseNamedCommandLookup(actionNumber)
    if actionId == nil then
        return actionNumber
    else
        return '_' .. actionId
    end
end

function getReaperActionNameOrCommandId(actionNamedCommandID)
    actionNamedCommandID = (type(actionNamedCommandID) == 'string') and '_' .. actionNamedCommandID or
                               actionNamedCommandID
    local actionNumber = reaper.NamedCommandLookup(actionNamedCommandID)
    if r.APIExists('CF_GetCommandText') then -- if SWS, return name
        return true, r.CF_GetCommandText(0, actionNumber)
    else -- otherwise Fallback to Action ID
        return false, getReaperActionCommandId(actionNumber)
    end
end

function deleteLongerProjExtState(section, key)
    local n = '*'
    while r.GetProjExtState(0, section, key .. n) == 1 do
        r.SetProjExtState(0, section, key .. n, '')
        n = n .. '*'
    end
end

function saveLongProjExtState(section, key, val)
    local maxLength = 2 ^ 12 - #key - 2
    deleteLongerProjExtState(section, key)
    r.SetProjExtState(0, section, key, val:sub(1, maxLength))
    if #val > maxLength then
        saveLongProjExtState(section, key .. '*', val:sub(maxLength + 1, #val))
    end
end

function loadLongProjExtKey(section, key)
    local i = 0
    local maxLength = 2 ^ 12 - #key - 2
    while true do
        retval, k, val = r.EnumProjExtState(0, section, i)
        if not retval then
            break
        end
        if (k == key) then
            if #val == maxLength then
                val = val .. (loadLongProjExtKey(section, key .. '*') or '')
            end
            return val
        end
        i = i + 1
    end
end
