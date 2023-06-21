-- @noindex
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