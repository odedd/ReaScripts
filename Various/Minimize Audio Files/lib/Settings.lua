-- @noindex
settings = {}

MAIN_OPERATION = {
    MINIMIZE = 0,
    BACKUP = 1
}
MAIN_OPERATION_DESCRIPTIONS = {
    [MAIN_OPERATION.MINIMIZE] = 'Minimize files in project',
    [MAIN_OPERATION.BACKUP] = 'Backup to a new folder with minimized files'
}
for i = 0, #MAIN_OPERATION_DESCRIPTIONS do
    MAIN_OPERATIONS_LIST = (MAIN_OPERATIONS_LIST or '') .. MAIN_OPERATION_DESCRIPTIONS[i] .. '\0'
end

-- bitwise
BACKUP_OPERATION = {
    RS5K = 1,
    VIDEO = 2,
    EXTERNAL = 4
}
BACKUP_OPERATION_DESCRIPTIONS = {
    [BACKUP_OPERATION.RS5K] = {
        order = 0,
        label = "rs5k samples",
        hint = 'ReaSamplOmatic5000 samples'
    },
    [BACKUP_OPERATION.VIDEO] = {
        order = 1,
        label = "video files",
        hint = 'Video files'
    },
    [BACKUP_OPERATION.EXTERNAL] = {
        order = 2,
        label = "external files",
        hint = 'External audio files'
    }
}

DELETE_OPERATION = {
    MOVE_TO_TRASH = 0,
    DELETE_FROM_DISK = 1,
    KEEP_IN_FOLDER = 2
}

DELETE_OPERATION_DESCRIPTIONS = {
    [DELETE_OPERATION.MOVE_TO_TRASH] = 'Move originals to trash',
    [DELETE_OPERATION.DELETE_FROM_DISK] = 'Delete originals immediately (caution!)',
    [DELETE_OPERATION.KEEP_IN_FOLDER] = 'Keep originals'
}

for i = 0, #DELETE_OPERATION_DESCRIPTIONS - 1 do
    DELETE_OPERATIONS_LIST = (DELETE_OPERATIONS_LIST or '') .. DELETE_OPERATION_DESCRIPTIONS[i] .. '\0'
end

MINIMIZE_SOURCE_TYPES = {
    UNCOMPRESSED_ONLY = 0,
    ALL = 1
}
MINIMIZE_SOURCE_TYPES_DESCRIPTIONS = {
    [MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_ONLY] = 'Uncompressed (PCM) only',
    [MINIMIZE_SOURCE_TYPES.ALL] = 'All source types (might result in larger media size)'
}
for i = 0, #MINIMIZE_SOURCE_TYPES_DESCRIPTIONS do
    MINIMIZE_SOURCE_TYPES_LIST = (MINIMIZE_SOURCE_TYPES_LIST or '') .. MINIMIZE_SOURCE_TYPES_DESCRIPTIONS[i] .. '\0'
end

function getDefaultSettings(factory)
    if factory == nil then
        factory = false
    end
    local settings = {
        default = {
            mainOperation = MAIN_OPERATION.BACKUP,
            minimizeSourceTypes = MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_ONLY,
            deleteOperation = DELETE_OPERATION.MOVE_TO_TRASH,
            backupOperation = BACKUP_OPERATION.RS5K + BACKUP_OPERATION.VIDEO,
            keepMediaFolderStructure = true,
            padding = 1,
            suffix = '_m'
        }
    }

    if not factory then
        local loaded_ext_settings = table.load(scr.dfsetfile) or {}
        for k, v in pairs(loaded_ext_settings or {}) do
            settings.default[k] = v
        end
    end

    return settings
end

function loadSettings()
    local st = getDefaultSettings()
    settings = deepcopy(st.default)
end

function saveSettings()
    table.save(settings, scr.dfsetfile)
end

function checkSettings()
    local errors = {}
    if settings.mainOperation == MAIN_OPERATION.BACKUP then
        if settings.backupDestination == nil then
            table.insert(errors, 'Must select destination folder')
        elseif not isFolderEmpty(settings.backupDestination) then
            table.insert(errors, 'Destination folder must be empty')
        end
    end 
    return #errors == 0, errors
end