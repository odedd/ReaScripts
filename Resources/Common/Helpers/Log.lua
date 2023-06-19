local function __FILE__(depth) return debug.getinfo(depth, 'S').source end
local function __LINE__(depth) return debug.getinfo(depth, 'l').currentline end
local function __FUNC__(depth) return debug.getinfo(depth, 'n').name end

local function getLogCodePosition(depth)
    depth = depth or 3
    local _, file, ext = OD_DissectFilename(__FILE__(depth))
    return (file .. (ext and ('.' .. ext) or '') .. "#" .. __LINE__(depth) .. " (" .. __FUNC__(depth) .. ")")
end

local function log(level, msg, msg_val, func_offset)
    if level.level <= App.debugLevel.level then
        reaper.ShowConsoleMsg(
            level.name..' '..os.date("%c") .. ' ' .. getLogCodePosition(5+(func_offset or 0)) .. ": " ..
            msg .. (msg_val and (' (' .. tostring(msg_val) .. ')') or '') .. '\n')
    end
    return msg_val
end

function OD_LogInfo(msg, msg_val, func_offset)
    return log(DEBUG_LEVEL.INFO, msg, msg_val, func_offset)
end

function OD_LogError(msg, msg_val, func_offset)
    return log(DEBUG_LEVEL.ERROR, msg, msg_val, func_offset)
end
