-- @noindex

function folderSep()
    return os_is.win and '\\' or '/'
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
end

-- file_exists works in mac but fails in windows under some conditions. this works in both (but fails as a total replacement for file_exists)
function folder_exists(file)
    local ok, err, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    if ok == nil then ok = false end
    return ok, err
end

function generateUniqueFilename(filename)
    -- Check if the file already exists
    if file_exists(filename) then
        local counter = 1
        local path, name, ext = string.match(filename, "(.-)([^\\/]-).([^%.]+)$")
        local newFilename
        repeat
            counter = counter + 1
            newFilename = path .. name .. "_" .. counter .. "." .. ext
        until not file_exists(newFilename)
        -- reaper.ShowConsoleMsg(('generateUniqueFilename: new file name! (%s)\n'):format(newFilename))
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

-- returns relPath, isRelative:
--   relPath - filename in relative form, if possible
--   isRelative - true if relative, false if absolute
function getRelativeOrAbsolutePath(fileName, rootPath)
    local relPath = fileName:gsub('^' .. escape_pattern(rootPath), '')
    return (relPath and relPath or fileName), (relPath ~= fileName)
end

function getSubfolders(folder)
    local folders = {}
    local i = 0
    repeat
        local retval = r.EnumerateSubdirectories(folder, i)
        table.insert(folders, retval)
        i = i + 1
    until not retval
    return folders
end

function getFilesInFolder(folder, ignore_ds)
    local files = {}
    local i = 0
    repeat
        local retval = r.EnumerateFiles(folder, i)
        if retval and ((not ignore_ds) or retval ~= '.DS_Store') then
            table.insert(files, retval)
        end
        i = i + 1
    until not retval
    return files
end

function isFolderEmpty(folder)
    local files = getFilesInFolder(folder, true)
    return r.EnumerateSubdirectories(folder, 0) == nil and #files == 0
end

-- function by amagalma. thanks!
function copyFile(old_path, new_path)
    local old_file = io.open(old_path, "rb")
    local new_file = io.open(new_path, "wb")
    local old_file_sz, new_file_sz = 0, 0
    if not old_file or not new_file then
        if old_file then old_file:close() end
        if new_file then new_file:close() end
        -- reaper.ShowConsoleMsg('copyFile: fail at (1): old_file: '..(old_file and 'ok' or 'error')..', new_file: '..(new_file and 'ok' or 'error')..'\n')
        -- reaper.ShowConsoleMsg('                       old_path: '..old_path..'\n')
        -- reaper.ShowConsoleMsg('                       new_path: '..new_path..'\n')
        return false
    end
    while true do
        local block = old_file:read(2 ^ 13)
        if not block then
            old_file_sz = old_file:seek("end")
            break
        end
        new_file:write(block)
    end
    old_file:close()
    new_file_sz = new_file:seek("end")
    new_file:close()
    -- if not (new_file_sz == old_file_sz) then reaper.ShowConsoleMsg('copyFile: fail at (2)\n') end
    return new_file_sz == old_file_sz
end

function moveFile(old_path, new_path)
    local success = os.rename(old_path, new_path)
    -- reaper.ShowConsoleMsg(('moveFile: old_path=%s | new_path=%s\n'):format(old_path,new_path))
    if success then
        -- reaper.ShowConsoleMsg('moveFile: success on (1)\n')
        return true
    else -- if moving using rename failed, resort to copy + delete
        -- reaper.ShowConsoleMsg('moveFile: trying copy (2)\n')
        if copyFile(old_path, new_path) then
            -- reaper.ShowConsoleMsg('moveFile: success on copy. trying to remove... (3)\n')
            return os.remove(old_path)
        else
            -- reaper.ShowConsoleMsg('moveFile: fail on copy (4)\n')
            return false
        end
    end
end

function moveToTrash(filename)
    local trashPath
    if os_is.mac then
        trashPath = os.getenv("HOME") .. "/.Trash/"
    elseif os_is.lin then
        trashPath = os.getenv("HOME") .. "/.local/share/Trash/files/"
    elseif os_is.win then
        local escaped_filename = filename:gsub('\'','\'\'') --escape for powershell
        local cmd = ([[
@powershell.exe -nologo -noprofile -Command "& {Add-Type -AssemblyName 'Microsoft.VisualBasic'; Get-ChildItem -Path '%s' | ForEach-Object { if ($_ -is [System.IO.DirectoryInfo]) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($_.FullName,'OnlyErrorDialogs','SendToRecycleBin') } else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_.FullName,'OnlyErrorDialogs','SendToRecycleBin') } } }"
]]):format(escaped_filename)
    -- reaper.ShowConsoleMsg(cmd..'\n')
        return os.execute(cmd)
        -- return reaper.ExecProcess(cmd,0)
    -- windows not yet clear
    else
        return false
    end

    local _, Fn, ext = dissectFilename(filename)
    if not folder_exists(trashPath) then return false end

    local fileInTrashPath = trashPath..Fn..'.'..ext
    return moveFile(filename, fileInTrashPath)
end

function getFormattedFileSize(fileSize)
    if fileSize == nil then return '' end
    local suffixes = {"B", "KB", "MB", "GB", "TB"}
    local i = 1

    while fileSize >= 1000 and i < #suffixes do
        fileSize = fileSize / 1000
        i = i + 1
    end

    return string.format("%.2f %s", fileSize, suffixes[i])
end

function getFileSize(fileName)
    -- reaper.ShowConsoleMsg(('getFileSize for: %s '):format(fileName))
    local file = io.open(fileName, "rb")
    if file then
        local fileSize = file:seek("end")
        file:close()
        -- reaper.ShowConsoleMsg(fileSize..'\n')
        return fileSize
    else
        -- reaper.ShowConsoleMsg('failed\n')
        return nil
    end
end
