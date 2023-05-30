-- @noindex

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function generateUniqueFilename(filename)
    -- Check if the file already exists
    if reaper.file_exists(filename) then
        local counter = 1
        local path, name, ext = string.match(filename, "(.-)([^\\/]-).([^%.]+)$")
        repeat
            counter = counter + 1
            newFilename = path .. name .. "_" .. counter .. "." .. ext
        until not reaper.file_exists(newFilename)
        return newFilename
    else
        return filename
    end
end

function getContent(path)
    local file = io.open(path)
    if not file then
        return ""
    end
    local content = file:read("*a")
    file:close()
    return content
end

function dissectFilename(path)
    return string.match(path, "(.-)([^\\/]-).([^%.]+)$") -- path, name, ext
end