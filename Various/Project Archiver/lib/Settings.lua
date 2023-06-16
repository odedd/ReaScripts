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
            collect = COLLECT.RS5K + COLLECT.VIDEO + COLLECT.EXTERNAL, -- TODO implement RS5K collection
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
    if r.GetPlayState() & 4 == 4 then
        table.insert(errors, "Reaper cannot be recording while minimizing")
    end
    if Settings.backup then
        if Settings.backupDestination == nil then
            table.insert(errors, 'Must select destination folder')
        elseif not OD_FolderExists(Settings.backupDestination) then
            table.insert(errors, 'Destination folder does not exist')
        elseif not OD_IsFolderEmpty(Settings.backupDestination) then
            table.insert(errors, 'Destination folder must be empty')
        end
    end
    return #errors == 0, errors
end
