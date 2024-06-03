-- @noindex
function OD_FolderSep()
    -- return OS_is.win and '\\' or '/'
    return '/'
end

function OD_FileExists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
end

-- file_exists works in mac but fails in windows under some conditions. this works in both (but fails as a total replacement for file_exists)
function OD_FolderExists(file)
    local ok, err, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    if ok == nil then
        ok = false
    end
    return ok, err
end

function OD_GenerateUniqueFilename(filename)
    -- Check if the file already exists
    if OD_FileExists(filename) then
        local counter = 1
        local path, name, ext = string.match(filename, "(.-)([^\\/]-).([^%.]+)$")
        local newFilename
        repeat
            counter = counter + 1
            newFilename = path .. name .. '_' .. counter .. (ext and ('.' .. ext) or '')
        until not OD_FileExists(newFilename)
        return newFilename
    else
        return filename
    end
end

function OD_GetContent(path)
    local file = io.open(path)
    if not file then
        return ""
    end
    local content = file:read("*a")
    file:close()
    return content
end

-- returns path, name, ext
function OD_DissectFilename(path)
    return string.match(path, "(.-)([^\\/]-).([^%.]+)$") -- path, name, ext
end

-- returns relFile, relPath, isRelative:
--   relFile - filename in relative form, if possible
--   relPath - only path in relative form, if possible
--   isRelative - true if relative, false if absolute
function OD_GetRelativeOrAbsoluteFile(fileName, rootPath)
    local relFile = fileName:gsub('^' .. OD_EscapePattern(rootPath), '')
    local relPath = OD_DissectFilename(relFile)
    return (relFile and relFile or fileName), relPath, (relFile ~= fileName)
end

function OD_SanitizeFilename(name)
    -- replace special characters that are reserved on Windows
    return name:gsub('[*\\:<>?/|"%c]+', '-')
end

function OD_GetSubfolders(folder)
    local folders = {}
    local i = 0
    repeat
        local retval = r.EnumerateSubdirectories(folder, i)
        table.insert(folders, retval)
        i = i + 1
    until not retval
    return folders
end

function OD_GetFilesInFolder(folder, ext, ignore_ds)
    local files = {}
    local i = 0
    ext = ext:gsub('^%.', '')
    repeat
        local retval = r.EnumerateFiles(folder, i)
        if retval and retval:lower():match("%."..OD_EscapePattern(ext):lower()..'$') and ((not ignore_ds) or retval ~= '.DS_Store') then
            table.insert(files, retval)
        end
        i = i + 1
    until not retval
    return files
end

function OD_GetFilesInFolderAndSubfolders(folder, ext, ignore_ds)
    folder = folder:gsub('\\','/'):gsub('/$', '') -- remove trailing slash
    local files = OD_GetFilesInFolder(folder, ext, ignore_ds)
    local folders = OD_GetSubfolders(folder)
    for i, subfolder in ipairs(folders) do
        local subfiles = OD_GetFilesInFolderAndSubfolders(folder .. OD_FolderSep() .. subfolder, ext, ignore_ds)
        for j, subfile in ipairs(subfiles) do
            table.insert(files, subfolder .. OD_FolderSep() .. subfile)
        end
    end
    return files
end

function OD_IsFolderEmpty(folder)
    local files = OD_GetFilesInFolder(folder, nil, true)
    return r.EnumerateSubdirectories(folder, 0) == nil and #files == 0
end

-- based on a function by amagalma. thanks!
function OD_CopyFile(old_path, new_path, logger)
    local logmsg = ('OD_CopyFile %s -> %s'):format(old_path, new_path)
    local old_file = io.open(old_path, "rb")
    local new_file = io.open(new_path, "wb")
    local old_file_sz, new_file_sz = 0, 0
    if not old_file or not new_file then
        if old_file then
            old_file:close()
        end
        if new_file then
            new_file:close()
        end
        if logger then logger:logError(logmsg, false, 1) end
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
    local success = (new_file_sz == old_file_sz)
    if logger then
        return logger:log(success and logger.LOG_LEVEL.DEBUG or logger.LOG_LEVEL.ERROR, logmsg, success)
    else
        return success
    end
end

function OD_MoveFile(old_path, new_path, logger)
    local logmsg = ('OD_MoveFile %s -> %s'):format(old_path, new_path)
    local success = os.rename(old_path, new_path)
    if success then
        if logger then logger:logDebug(logmsg, true, 1) end
        return true
    else -- if moving using rename failed, resort to copy + delete
        if logger then logger:logDebug(('OD_MoveFile - Move failed, resorting to copy+delete'), true, 1) end
        if OD_CopyFile(old_path, new_path, logger) then
            local success = os.remove(old_path)
            if logger then
                return logger:log(success and logger.LOG_LEVEL.DEBUG or logger.LOG_LEVEL.ERROR,
                    ('OD_MoveFile - Delete %s'):format(old_path),
                    success, 1)
            else
                return success
            end
        else
            return false
        end
    end
end

function OD_MoveToTrash(filename, logger)
    local logmsg
    local trashPath
    if OS_is.mac then
        trashPath = os.getenv("HOME") .. "/.Trash/"
    elseif OS_is.lin then
        trashPath = os.getenv("HOME") .. "/.local/share/Trash/files/"
    elseif OS_is.win then
        local escaped_filenames = {}
        local filenames
        if type(filename) == "string" then
            filenames = { filename }
        else
            filenames = filename
        end
        for i, fn in ipairs(filenames) do
            if logger then logger:logDebug('OD_MoveToTrash (powershell) adding to list', filename, 1) end
            table.insert(escaped_filenames, "'" .. fn:gsub('\'', '\'\'') .. "'") -- escape for powershell and engulf in '
        end
        local cmd =
            'powershell.exe -nologo -noprofile -Command "& {Add-Type -AssemblyName \'Microsoft.VisualBasic\'; Get-ChildItem -Path ' ..
            table.concat(escaped_filenames, ' , ') ..
            '| ForEach-Object { if ($_ -is [System.IO.DirectoryInfo]) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($_.FullName,\'OnlyErrorDialogs\',\'SendToRecycleBin\') } else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_.FullName,\'OnlyErrorDialogs\',\'SendToRecycleBin\') } } }"'
        if logger then logger:logDebug('OD_MoveToTrash->ExecProcess: %s', cmd, 1) end
        r.ExecProcess(cmd, 0)
        -- check if the files were indeed moved away from the original place
        for i, fn in ipairs(filenames) do
            if OD_FileExists(fn) then
                if logger then logger:logError('OD_MoveToTrash - file still exists', fn, 1) end
                return false
            end
        end
        return true
        -- return os.execute(cmd)
    else
        return false
    end

    local _, Fn, ext = OD_DissectFilename(filename)
    if not OD_FolderExists(trashPath) then
        if logger then logger:logError('OD_MoveToTrash %s - trash folder does not exist', trashPath, 1):format(filename) end
        return false
    end

    local fileInTrashPath = trashPath .. Fn .. (ext and ('.' .. ext) or '')
    if logger then logger:logDebug(('OD_MoveToTrash %s'):format(filename), nil, 1) end
    return OD_MoveFile(filename, fileInTrashPath, logger)
end

function OD_GetFormattedFileSize(fileSize)
    if fileSize == nil then
        return ''
    end
    local suffixes = { "B", "KB", "MB", "GB", "TB" }
    local i = 1
    local negative = fileSize < 0
    while math.abs(fileSize) >= 1000 and i < #suffixes do
        fileSize = math.abs(fileSize) / 1000
        i = i + 1
    end
    if negative and fileSize > 0 then fileSize = -1 * fileSize end

    return string.format("%.2f %s", fileSize, suffixes[i])
end

function OD_GetFileSize(fileName)
    local file = io.open(fileName, "rb")
    if file then
        local fileSize = file:seek("end")
        file:close()
        return fileSize
    else
        return nil
    end
end

function OD_LocalOrCommon(file, basePath)
    local p = basePath or debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
    if r.file_exists(p .. file) then
        return (p .. file)
    else
        return (p .. '../../' .. file)
    end
end
