-- @noindex
Settings = {}

-- * local
local function getDefaultSettings(factory)
    if factory == nil then factory = false end
    local settings = {
        default = {
            backup = true,
            minimize = true,
            cleanMediaFolder = true,
            keepActiveTakesOnly = true,
            minimizeSourceTypes = MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS,
            deleteMethod = DELETE_METHOD.MOVE_TO_TRASH,
            collect = COLLECT.RS5K + COLLECT.VIDEO + COLLECT.EXTERNAL,
            collectOperation = COLLECT_OPERATION.COPY,
            keepMediaFolderStructure = true,
            glueFormat = GLUE_FORMATS.FLAC24,
            padding = 1,
            suffix = '_m',
            showMinimizeDoubleWarning = true,
            targetPaths = {
                [FILE_TYPES.VIDEO] = 'Video Files',
                [FILE_TYPES.RS5K] = 'RS5K Samples'
            }
        }
    }

    if not factory then
        local loaded_ext_settings = table.load(Scr.dfsetfile) or {}
        for k, v in pairs(loaded_ext_settings or {}) do
            settings.default[k] = v
        end
    end

    return settings
end

-- * public
function LoadSettings()
    local st = getDefaultSettings()
    Settings = OD_DeepCopy(st.default)
end

function SaveSettings()
    table.save(Settings, Scr.dfsetfile)
end

function CheckSettings()
    local errors = {}
    if not( Settings.backup or Settings.keepActiveTakesOnly or Settings.minimize or Settings.cleanMediaFolder or (Settings.collect ~= 0)) then
        table.insert(errors, TEXTS.ERROR_NOTHING_TO_DO)
        return false, errors
    end
    local projectName = r.GetProjectName( 0, '' )
    if projectName  == '' then
        table.insert(errors, 'Project must be saved')
        return false, errors
    end
    if r.CountMediaItems(0) == 0 then
        table.insert(errors, 'Project is empty')
        return false, errors
    end
    if OD_BfCheck(r.GetPlayState(),1) then
        table.insert(errors, "Reaper must be stopped while the script is running")
        return false, errors
    end
    if Settings.backup then
        if Settings.backupDestination == nil then
            table.insert(errors, TEXTS.ERROR_NO_BACKUP_DESTINATION)
        elseif not OD_FolderExists(Settings.backupDestination) then
            table.insert(errors, TEXTS.ERROR_BACKUP_DESTINATION_MISSING)
        elseif not OD_IsFolderEmpty(Settings.backupDestination) then
            table.insert(errors, TEXTS.ERROR_BACKUP_DESTINATION_MUST_BE_EMPTY)
        end
    else
        if Settings.cleanMediaFolder and Settings.deleteMethod == DELETE_METHOD.KEEP_IN_FOLDER then
            table.insert(errors, TEXTS.ERROR_KEEP_IN_FOLDER)
        end
    end
    return #errors == 0, errors
end
