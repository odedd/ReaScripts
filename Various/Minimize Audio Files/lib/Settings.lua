-- @noindex

settings = {}

DELETE_OPERATIONS = {
    MOVE_TO_TRASH = 0,
    DELETE_FROM_DISK = 1,
    KEEP_IN_FOLDER = 2
}

DELETE_OPERATION_DESCRIPTIONS = {
    [DELETE_OPERATIONS.MOVE_TO_TRASH] = 'Move originals to trash',
    [DELETE_OPERATIONS.DELETE_FROM_DISK] = 'Delete originals immediately (caution!)',
    [DELETE_OPERATIONS.KEEP_IN_FOLDER] = 'Keep originals'
}

for i = 0, #DELETE_OPERATION_DESCRIPTIONS do
    DELETE_OPERATIONS_LIST = (DELETE_OPERATIONS_LIST or '') .. DELETE_OPERATION_DESCRIPTIONS[i] .. '\0'
end

MAIN_OPERATION = {
    MINIMIZE = 0,
    BACKUP = 1
}

function getDefaultSettings(factory)
    if factory == nil then
        factory = false
    end
    local settings = {
        default = {
            padding = 1,
            suffix = '_m',
            deleteOperation = DELETE_OPERATIONS.MOVE_TO_TRASH,
            operation = MAIN_OPERATION.MINIMIZE
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