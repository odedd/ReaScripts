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
    return int ~ bit
end

-- Convert to a string showing an integer as a binary number
function OD_ToBitString(num, bits)
    local frexp = function(x)
        local abs, floor, log = math.abs, math.floor, math.log
        local log2 = log(2)

        return function(x)
            if x == 0 then return 0.0, 0.0 end
            local e = floor(log(abs(x)) / log2)
            if e > 0 then
                -- Why not x / 2^e? Because for large-but-still-legal values of e this
                -- ends up rounding to inf and the wheels come off.
                x = x * 2 ^ -e
            else
                x = x / 2 ^ e
            end
            -- Normalize to the range [0.5,1)
            if abs(x) >= 1.0 then
                x, e = x / 2, e + 1
            end
            return x, e
        end
    end

    -- returns a table of bits, most significant first.
    bits = bits or math.max(1, select(2, frexp(num)))
    local t = {} -- will contain the bits
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return table.concat(t)
end
