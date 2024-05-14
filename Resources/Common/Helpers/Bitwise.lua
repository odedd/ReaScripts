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

-- Convert to a string showing an integer as a binary number
function OD_ToBitString(num,bits)
    -- returns a table of bits, most significant first.
    bits = bits or math.max(1, select(2, math.frexp(num)))
    local t = {} -- will contain the bits        
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return table.concat(t)
end
