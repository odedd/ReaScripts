-- @noindex

-- BitField set
-- for example: to set &4 in x to true, call OD_bfSet(x, 4, true)
function OD_BfSet(int, bit, enabled)
    return enabled and (int | bit) or (int & (~bit))
end

-- BitField check
function OD_BfCheck(int, bit)
    return (int & bit ~= 0)
end

-- BitField toggle
function OD_BfToggle(int, bit)
    return int ~bit
end