-- @noindex

OD_Logger = {
    LOG_LEVEL = {
        NONE = 0,
        ERROR = 1,
        INFO = 2,
        DEBUG = 3
    },
    LOG_OUTPUT = {
        CONSOLE = 0,
        FILE = 1
    }
}

function OD_Logger:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

function OD_Logger:init()
    self.LOG_LEVEL_INFO = {
        [self.LOG_LEVEL.NONE] = {order = self.LOG_LEVEL.NONE, name = "NONE", description = "None"},
        [self.LOG_LEVEL.ERROR] = {order = self.LOG_LEVEL.ERROR, name = "ERROR", description = "Errors only"},
        [self.LOG_LEVEL.INFO] = {order = self.LOG_LEVEL.INFO, name = "INFO", description = "Information & Errors"},
        [self.LOG_LEVEL.DEBUG] = {order = self.LOG_LEVEL.DEBUG, name = "DEBUG", description = "Everything (A lot!)"},
    }
    self.level = self.level or self.LOG_LEVEL.INFO
    self.output = self.output or self.LOG_OUTPUT.CONSOLE

    reaper.atexit(function () self:exit() end)
end

function OD_Logger:__FILE__(depth) return debug.getinfo(depth, 'S').source end
function OD_Logger:__LINE__(depth) return debug.getinfo(depth, 'l').currentline end
function OD_Logger:__FUNC__(depth) return debug.getinfo(depth, 'n').name end

function OD_Logger:getLogFile()
    if self.file and OD_FileExists(self.filename) then return self.file end
    if self.filename == nil then 
        self.output = self.LOG_OUTPUT.CONSOLE
        self:logError('No log filename defined. resorting to console')
        return false
    end
    self.file = io.open(self.filename, "a")
    return self.file
end
function OD_Logger:closeLogFile()
    if self.file then
        self.file:flush()
        self.file:close()
        self.file = nil
        return true
    else
        return false
    end
end
function OD_Logger:flush()
    if self.file then
        self.file:flush()
        return true
    else
        return false
    end
end
function OD_Logger:sendToLog(msg)
    if self.output == self.LOG_OUTPUT.FILE then
        local file = self:getLogFile()
        if file then
            file:write(msg..'\n')
        end
    end
    if self.output == self.LOG_OUTPUT.CONSOLE then
        reaper.ShowConsoleMsg(msg..'\n')
    end
end
function OD_Logger:getLogCodePosition(depth)
    depth = depth or 2
    local funcDepth = self:__FUNC__(depth)
    local _, file, ext = OD_DissectFilename(tostring(self:__FILE__(depth)))
    return (file .. (ext and ('.' .. ext) or '') .. "#" .. tostring(self:__LINE__(depth)) .. (funcDepth and " (" .. tostring(self:__FUNC__(depth)) .. ")" or ""))
end

function OD_Logger:log(level, msg, msg_val, depth_offset)
    if level <= self.level then
        local fullMsg =
            self.LOG_LEVEL_INFO[level].name..' '..os.date("%c") .. ' ' .. self:getLogCodePosition(4+(depth_offset or 0)) .. ": " ..
            msg .. ((msg_val ~= nil) and (' (' .. tostring(msg_val) .. ')') or '')
            self:sendToLog(fullMsg)
    end
    return msg_val
end

function OD_Logger:logDebug(msg, msg_val, depth_offset)
    return self:log(self.LOG_LEVEL.DEBUG, msg, msg_val, depth_offset)
end
function OD_Logger:logInfo(msg, msg_val, depth_offset)
    return self:log(self.LOG_LEVEL.INFO, msg, msg_val, depth_offset)
end
function OD_Logger:logError(msg, msg_val, depth_offset)
    return self:log(self.LOG_LEVEL.ERROR, msg, msg_val, depth_offset)
end

function OD_Logger:logTable(level, tableName, table, depth_offset)
    for k,v in pairs(table) do
        if type(v) ~= 'table' then
            self:log(level, (tableName..'.%s'):format(k), v, (depth_offset or 0)+1)
        else
            self:logTable(level,tableName..'.'..tostring(k),v, (depth_offset or 0) + 1)
        end
    end

end

function OD_Logger:logAppInfo(level, app)
    self:log(level,'OS: ', reaper.GetOS())
    self:log(level,'Reaper version: ', r.GetAppVersion():match("[%d%.]+"))
    self:log(level,'Script file: ', app.scr.path)
    self:log(level,'Script version: ', tostring(app.scr.version))
    -- self:logInfo(level,'JS_ReaScriptAPI version: ', tostring(r.APIExists('JS_ReaScriptAPI_Version')))
end

function OD_Logger:setLogFile(filename)
    if filename ~= self.filename then self:closeLogFile() end
    local path, basename, ext = OD_DissectFilename(filename)
    if basename ~= nil and ext ~= nil then
        self.filename = filename
    else
        self.filename = nil
    end
end
function OD_Logger:exit()
    self:closeLogFile()
end