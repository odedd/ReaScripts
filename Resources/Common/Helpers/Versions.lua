-- @noindex
function OD_GetMajorVersion(v)
    return v and tonumber(v:match('^(.-)%.')) or 0
end
function OD_GetMinorVersion(v)
    return v and tonumber(v:match('%.(.-)')) or 0
end
function OD_IsVersionAtLeast(currentVersion, minVersion)
    if not currentVersion or not minVersion then
        return false
    end
    
    -- Split versions into components
    local function splitVersion(version)
        local parts = {}
        for part in string.gmatch(version, '([^%.]+)') do
            table.insert(parts, tonumber(part) or 0)
        end
        return parts
    end
    
    local current = splitVersion(currentVersion)
    local minimum = splitVersion(minVersion)
    
    -- Compare each component
    local maxParts = math.max(#current, #minimum)
    for i = 1, maxParts do
        local currentPart = current[i] or 0
        local minPart = minimum[i] or 0
        
        if currentPart > minPart then
            return true
        elseif currentPart < minPart then
            return false
        end
    end
    
    return true -- versions are equal
end