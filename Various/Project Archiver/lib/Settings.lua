-- @noindex
Settings = {}

-- ! CONSTANTS

-- bitwise
COLLECT = {
    EXTERNAL = 1,
    VIDEO = 2,
    RS5K = 4
}
COLLECT_DESCRIPTIONS = {
    [COLLECT.EXTERNAL] = {
        order = 0,
        label = "External unminimized audio files",
        hint = 'Copy all external audio files which were have not been minimized to the project\'s media folder'
    },
    [COLLECT.VIDEO] = {
        order = 1,
        label = "Video files",
        hint = 'Copy all video files to the project\'s media folder'
    },
    [COLLECT.RS5K] = {
        order = 2,
        label = "RS5K samples",
        hint = 'Copy all used ReaSamplOmatic5000 samples to the project\'s media folder'
    }
}

COLLECT_OPERATION = {
    COPY = 0,
    MOVE = 1
}
COLLECT_BACKUP_OPERATION = {
    COPY = 0,
    MOVE = 1
}

COLLECT_OPERATION_DESCRIPTIONS = {
    [COLLECT_OPERATION.COPY] = 'Copy from original location',
    [COLLECT_OPERATION.MOVE] = 'Move from original location'
}


for i = 0, #COLLECT_OPERATION_DESCRIPTIONS do
    COLLECT_OPERATIONS_LIST = (COLLECT_OPERATIONS_LIST or '') .. COLLECT_OPERATION_DESCRIPTIONS[i] .. '\0'
end

DELETE_METHOD = {
    MOVE_TO_TRASH = 0,
    DELETE_FROM_DISK = 1,
    KEEP_IN_FOLDER = 2
}

DELETE_METHOD_DESCRIPTIONS = {
    [DELETE_METHOD.MOVE_TO_TRASH] = 'Move originals to trash',
    [DELETE_METHOD.DELETE_FROM_DISK] = 'Delete originals immediately',
    [DELETE_METHOD.KEEP_IN_FOLDER] = 'Keep originals'
}

for i = 0, #DELETE_METHOD_DESCRIPTIONS do
    DELETE_METHODS_LIST = (DELETE_METHODS_LIST or '') .. DELETE_METHOD_DESCRIPTIONS[i] .. '\0'
end

MINIMIZE_SOURCE_TYPES = {
    UNCOMPRESSED_AND_LOSSLESS = 0,
    ALL = 1
}
MINIMIZE_SOURCE_TYPES_DESCRIPTIONS = {
    [MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS] = 'Uncompressed & Lossless only',
    [MINIMIZE_SOURCE_TYPES.ALL] = 'All audio source types'
}
for i = 0, #MINIMIZE_SOURCE_TYPES_DESCRIPTIONS do
    MINIMIZE_SOURCE_TYPES_LIST = (MINIMIZE_SOURCE_TYPES_LIST or '') .. MINIMIZE_SOURCE_TYPES_DESCRIPTIONS[i] .. '\0'
end

GLUE_FORMATS = {
    WAV24 = 0,
    WAV32F = 1,
    FLAC24 = 2,
    WAVPACK24 = 3,
    WAVPACK32F = 4
}

GLUE_FORMATS_DETAILS = {
    [GLUE_FORMATS.WAV24] = {
        description = 'WAV 24bit',
        formatString = 'ZXZhdxgAAA=='
    },
    [GLUE_FORMATS.WAV32F] = {
        description = 'WAV 32bit fp',
        formatString = 'ZXZhdyAAAA=='
    },
    [GLUE_FORMATS.FLAC24] = {
        description = 'FLAC 24bit',
        formatString = 'Y2FsZhgAAAAIAAAA'
    },
    [GLUE_FORMATS.WAVPACK24] = {
        description = 'WAVPACK 24bit',
        formatString = 'a3B2dwAAAAABAAAAAAAAAAEAAAA='
    },
    [GLUE_FORMATS.WAVPACK32F] = {
        description = 'WAVPACK 32bit fp',
        formatString = 'a3B2dwAAAAADAAAAAAAAAAEAAAA='
    }
}
for i = 0, #GLUE_FORMATS_DETAILS do
    GLUE_FORMATS_LIST = (GLUE_FORMATS_LIST or '') .. GLUE_FORMATS_DETAILS[i].description .. '\0'
end

-- * local
local function getDefaultSettings(factory)
    if factory == nil then factory = false end
    local settings = {
        default = {
            backup = true,
            minimize = true,
            cleanMediaFolder = true,
            keepActiveTakesOnly = true, -- TODO implement Settings.keepActiveTakesOnly (unless item marked with "play all takes")
            minimizeSourceTypes = MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS,
            deleteMethod = DELETE_METHOD.MOVE_TO_TRASH,
            collect = COLLECT.RS5K + COLLECT.VIDEO + COLLECT.EXTERNAL, -- TODO implement RS5K collection
            collectOperation = COLLECT_OPERATION.COPY,
            keepMediaFolderStructure = true,
            glueFormat = GLUE_FORMATS.FLAC24,
            padding = 1,
            suffix = '_m',
            showMinimizeDoubleWarning = true,
            targetPaths = { -- TODO add user setting for targetPaths
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
