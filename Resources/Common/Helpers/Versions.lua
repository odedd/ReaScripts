-- @noindex
function OD_GetMajorVersion(v)
    return tonumber(v:match('^(.-)%.'))
end
function OD_GetMinorVersion(v)
    return tonumber(v:match('^(.+)%.'))
end