-- @noindex

LOG_LEVEL = {
    NONE = { level = 0, name = "NONE" },
    ERROR = { level = 1, name = "ERROR" },
    INFO = { level = 2, name = "INFO" },
    DEBUG = { level = 3, name = "DEBUG" }
}

LOG_OUTPUT = {
    CONSOLE = 0,
    FILE = 1
}
Log = {
    level = LOG_LEVEL.INFO,
    output = LOG_OUTPUT.CONSOLE
}

local function __FILE__(depth) return debug.getinfo(depth, 'S').source end
local function __LINE__(depth) return debug.getinfo(depth, 'l').currentline end
local function __FUNC__(depth) return debug.getinfo(depth, 'n').name end

local function getLogFile()
    if Log.file then return Log.file end
    if Log.filename == nil then 
        Log.output = LOG_OUTPUT.CONSOLE
        OD_LogError('No log filename defined. resorting to console')
        return false
    end
    Log.file = io.open(Log.filename, "a")
    return Log.file
end
local function closeLogFile()
    if Log.file then
        Log.file:close()
        return true
    else
        return false
    end
end
local function sendToLog(msg)
    if Log.output == LOG_OUTPUT.FILE then
        local file = getLogFile()
        if file then
            file:write(msg..'\n')
        end
    end
    if Log.output == LOG_OUTPUT.CONSOLE then
        reaper.ShowConsoleMsg(msg..'\n')
    end
end
local function getLogCodePosition(depth)
    depth = depth or 2
    local _, file, ext = OD_DissectFilename(tostring(__FILE__(depth)))
    return (file .. (ext and ('.' .. ext) or '') .. "#" .. tostring(__LINE__(depth)) .. " (" .. tostring(__FUNC__(depth)) .. ")")
end

function OD_Log(level, msg, msg_val, depth_offset)
    if level.level <= Log.level.level then
        local fullMsg =
            level.name..' '..os.date("%c") .. ' ' .. getLogCodePosition(4+(depth_offset or 0)) .. ": " ..
            msg .. (msg_val and (' (' .. tostring(msg_val) .. ')') or '')
            sendToLog(fullMsg)
    end
    return msg_val
end

function OD_LogDebug(msg, msg_val, depth_offset)
    return OD_Log(LOG_LEVEL.DEBUG, msg, msg_val, depth_offset)
end
function OD_LogInfo(msg, msg_val, depth_offset)
    return OD_Log(LOG_LEVEL.INFO, msg, msg_val, depth_offset)
end
function OD_LogError(msg, msg_val, depth_offset)
    return OD_Log(LOG_LEVEL.ERROR, msg, msg_val, depth_offset)
end

function OD_LogTable(level, tableName, table, depth_offset)
    for k,v in pairs(table) do
        if type(v) ~= 'table' then
            OD_Log(level, (tableName..'.%s'):format(k), v, depth_offset)
        else
            OD_LogTable(level,tableName..'.'..tostring(k),v, (depth_offset or 0) + 1)
        end
    end

end
local function exit()
    closeLogFile()
end

reaper.atexit(exit)