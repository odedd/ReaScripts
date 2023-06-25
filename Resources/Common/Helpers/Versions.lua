-- @noindex
function OD_GetMajorVersion(v)
    return v and tonumber(v:match('^(.-)%.')) or 0
end
function OD_GetMinorVersion(v)
    return v and tonumber(v:match('^(.+)%.')) or 0
end