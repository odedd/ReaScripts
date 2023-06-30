-- @noindex
function OD_GetMajorVersion(v)
    return v and tonumber(v:match('^(.-)%.')) or 0
end
function OD_GetMinorVersion(v)
    return v and tonumber(v:match('^%d+%.(%d+)%.?%d*')) or 0
end
function OD_GetPatchVersion(v)
    return v and tonumber(v:match('^%d+%.%d+%.(%d+)')) or 0
end
function OD_GetRCVersion(v)
    return v and tonumber(v:match('^%d+%.%d+%.%d+rc(%d+)')) or 0
end

function OD_CheckVersionRequirement(version_to_check, required_version)
    local major_version = OD_GetMajorVersion(version_to_check)
    local minor_version = OD_GetMinorVersion(version_to_check)
    local patch_version = OD_GetPatchVersion(version_to_check)
    local rc_version = OD_GetRCVersion(version_to_check)
    local req_major_version = OD_GetMajorVersion(required_version)
    local req_minor_version = OD_GetMinorVersion(required_version)
    local req_patch_version = OD_GetPatchVersion(required_version)
    local req_rc_version = OD_GetRCVersion(required_version)
    local versionMatch = true
    if major_version < req_major_version then
        versionMatch = false
    elseif major_version == req_major_version then
        if minor_version < req_minor_version then
            versionMatch = false
        elseif minor_version == req_minor_version then
            if patch_version < req_patch_version then
                versionMatch = false
            elseif patch_version == req_patch_version then
                if rc_version < req_rc_version then
                    versionMatch = false
                end
            end
        end
    end
    return versionMatch
end