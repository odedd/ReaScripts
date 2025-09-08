-- @noindex
-- @description Adjust envelope segment size using mousewheel
-- @author Oded Davidov
-- @version 1.0.0
r = reaper

-- if you want the zoom level to affect the mousewheel sensitivity, uncomment the following line and comment the line after it
-- local MW_SCALE = 1 / r.GetHZoomLevel() / 3
local MW_SCALE = 0.008

-- if you want to reverse the mousewheel direction, set this to true
local REVERSE_MOUSEWHEEL = false

local MIN_DISTANCE = 0.00001 -- minimum distance between points
function main()
    if not r.APIExists('BR_GetMouseCursorContext') then
        r.ShowMessageBox("This script requires the SWS/S&M extension.", "Error", 0)
        return
    end

    local window, segment, details    = r.BR_GetMouseCursorContext()
    local env, istakeEnvelope         = r.BR_GetMouseCursorContext_Envelope()
    local prevIdx, nextIdx, prevTime, nextTime, found, automationItemIdx
    local _, _, _, _, _, _, direction = r.get_action_context()

    if env or details == 'env_segment' then
        local function checkPointsAroundPos(pos, env, automationItemIdx)
            automationItemIdx = automationItemIdx or -1
            local prev, time, prevTime
            local numPoints = r.CountEnvelopePointsEx(env, automationItemIdx)
            for i = 0, numPoints - 1 do
                _, time = r.GetEnvelopePointEx(env, automationItemIdx, i)
                if time < pos then
                    prev = i
                    prevTime = time
                end
                if time > pos then
                    if prev then return true, prev, i, prevTime, time end
                end
            end
            return false
        end

        local pos = r.BR_GetMouseCursorContext_Position()
        local numItems = r.CountAutomationItems(env)
        for i = 0, numItems - 1 do
            if not found then
                found, prevIdx, nextIdx, prevTime, nextTime = checkPointsAroundPos(pos, env, i)
                automationItemIdx = i
            end
        end
        -- if not found in automation items, look for underlying envelope
        if not found then
            automationItemIdx = -1
            found, prevIdx, nextIdx, prevTime, nextTime = checkPointsAroundPos(pos, env)
        end
        if found and prevIdx > 0 then
            local direction = direction * MW_SCALE * (REVERSE_MOUSEWHEEL and -1 or 1)

            local _, prevprevTime = r.GetEnvelopePointEx(env, automationItemIdx, prevIdx - 1)
            local _, nextnextTime = r.GetEnvelopePointEx(env, automationItemIdx, nextIdx + 1)
            if prevprevTime and nextnextTime and prevprevTime < prevTime and nextnextTime > nextTime then
                -- if distances are more than maxDistance, we can adjust the segment size
                if prevTime and nextTime then
                    local itemStartTime, itemEndTime
                    -- dont move past automation item bounds
                    if automationItemIdx ~= -1 then
                        itemStartTime = r.GetSetAutomationItemInfo(env, automationItemIdx, "D_POSITION", 0, false)
                        local itemLength = r.GetSetAutomationItemInfo(env, automationItemIdx, "D_LENGTH", 0, false)
                        itemEndTime = itemStartTime + itemLength
                    end
                    -- dont move past another point
                    local prevprevprevFound, prevprevprevTime = r.GetEnvelopePointEx(env, automationItemIdx, prevIdx - 2)
                    local prevprevDistance = math.min(direction,
                        prevprevprevFound and (prevprevTime - prevprevprevTime + MIN_DISTANCE) or direction)
                    local nextnextnextFound, nextnextnextTime = r.GetEnvelopePointEx(env, automationItemIdx, nextIdx + 2)
                    local nextnextDistance = math.min(direction,
                        nextnextnextFound and (nextnextnextTime - nextnextTime - MIN_DISTANCE) or direction)

                    -- dont move past the prev or next points
                    local newPrevPrevTime = prevprevTime - prevprevDistance
                    local newNextNextTime = nextnextTime + nextnextDistance
                    if newPrevPrevTime > prevTime - MIN_DISTANCE then
                        newPrevPrevTime = prevTime - MIN_DISTANCE
                    end
                    if newNextNextTime < nextTime + MIN_DISTANCE then
                        newNextNextTime = nextTime + MIN_DISTANCE
                    end

                    if automationItemIdx ~= -1 then
                        if newPrevPrevTime < itemStartTime + MIN_DISTANCE then
                            newPrevPrevTime = itemStartTime + MIN_DISTANCE
                        end
                        if newNextNextTime > itemEndTime - MIN_DISTANCE then
                            newNextNextTime = itemEndTime - MIN_DISTANCE
                        end
                    end

                    r.SetEnvelopePointEx(env, automationItemIdx, prevIdx - 1, newPrevPrevTime, nil, nil, nil, nil, true)
                    r.SetEnvelopePointEx(env, automationItemIdx, nextIdx + 1, newNextNextTime, nil, nil, nil, nil, true)
                    r.Envelope_SortPointsEx(env, automationItemIdx)
                end
            end
        end
    end
end
main()