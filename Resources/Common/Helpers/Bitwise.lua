-- @noindex

-- for example: to set &4 in x to true, call OD_bwSet(x, 4, true)
function OD_BwSet(var, bitVal, value)
    return var % bitVal + (value and 1 or 0) * bitVal
end

function OD_BwCheck(var, bitVal)
    return (var & bitVal ~= 0)
end