-- @noindex

settings = {}

DELETE_OPERATIONS = {
    MOVE_TO_TRASH = 'trash',
    KEEP_IN_FOLDER = 'keep',
    DELETE_FROM_DISK = 'delete'
}

function getDefaultSettings(factory)
    if factory == nil then
        factory = false
    end
    local settings = {
        default = {
            padding = 1,
            suffix = '_m',
            deleteOperation = DELETE_OPERATIONS.MOVE_TO_TRASH
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