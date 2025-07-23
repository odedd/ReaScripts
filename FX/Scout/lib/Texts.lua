-- @noindex
T = {}

T.PRESET_EDIT_MENU = {
    PRESET_NAME = {--TODO: Update this
        LABEL = 'Preset Name',
        HINT = 'A name for the new preset',
    },
    SHORTCUT = {
        LABEL = 'Shortcut Letter',
        HINT = 'A name for the new preset', 
    },
    ACTION = {
        LABEL = '',
        BUTTON = 'Export as Action',
        SUCCESS = 'Successfully created action:\n%s',
        HINT = 'temp',
    },
    SAVE = {
        LABEL = '',
        BUTTON_CREATE = 'Create Preset',
        BUTTON_EDIT = 'Save',
        HINT = 'temp',
    },
    CANCEL = {
        LABEL = '',
        BUTTON = 'Close',
        HINT = 'temp',
    }
}

T.SETTINGS = {
    CREATE_INSIDE_FODLER = {
        LABEL = 'Create sends inside folder',
        HINT = 'New send tracks can be created inside a folder track.',
    },
    SEND_FOLDER_NAME = {
        LABEL = 'Folder name',
        HINT = 'If one does not exist, it will be created when adding sends.',
    },
    FX_TYPE_ORDER = {
        LABEL = 'FX type priority',
        HINT = 'The order in which FX are displayed in the search window.',
    },
    SHORTCUTS = {
        CLOSE_SCRIPT = {
            LABEL = 'Close script',
            HINT = 'Shortcut to close script.',
        },
        HARD_CLOSE_SCRIPT = {
            LABEL = 'Hard Close script',
            HINT = 'Shortcut to hard close script (without persistant mode).',
        },
        NEW_SEND = {
            LABEL = 'New send',
            HINT = 'Shortcut to create a new send.',
        },
        NEW_RECV = {
            LABEL = 'New receive',
            HINT = 'Shortcut to create a new receive.',
        },
        NEW_HW = {
            LABEL = 'New hardware send',
            HINT = 'Shortcut to create a new hardware send.',
        },
        MARK_FAVORITE = {
            LABEL = 'Mark favorite',
            HINT = 'Mark search result as favorite.',
        },
    },
    UI_SCALE = {
        LABEL = 'Zoom',
        HINT = 'Interface scale. Double click to enter manually.',
    },
    EXPORT_TAGS = {
        LABEL = 'Tags, Presets and Favorites',
        BUTTON_LABEL = 'Export',
        HINT = 'Export user data for use on another system or as a backup.',
    },
    IMPORT_TAGS = {
        LABEL = '',
        BUTTON_LABEL = 'Import (Overwrite)',
        BUTTON_LABEL_MERGE = 'Import (Merge)',
        HINT = 'Import user data. Hold Shift to overwrite existing data.',
    }
}

T.SETTINGS.LISTS = {
}
T.SEARCH_WINDOW = {
    SEARCH_HINT = {
        [SEARCH_MODE.MAIN] = 'Item search | Press Tab to search filters',
        [SEARCH_MODE.FILTERS] = 'Filter search | Press Tab to search items',
    }
}
T.FILTER_NAMES = {
    [FILTER_TYPES.PRESET] = 'Preset',
    [FILTER_TYPES.TYPE] = 'Result Type',
    [FILTER_TYPES.FX_TYPE] = 'FX Type',
    [FILTER_TYPES.FOLDER] = 'Folder',
    [FILTER_TYPES.CATEGORY] = 'Category',
    [FILTER_TYPES.DEVELOPER] = 'Developer',
    [FILTER_TYPES.TAG] = 'Tag'
}
T.ERROR = {
    NO_DOCK = ([[
No previous dock found.

Please dock manually by dragging
the window to the dock of your choice.

After that, %s will remember
the dock position.]]):format(Scr.name)
}

T.IMPORT_SKIP_REASON = {
    [IMPORT_SKIP_REASON.ASSET_NOT_FOUND] = "Asset not found in current system",
    [IMPORT_SKIP_REASON.INCOMPATIBLE_VERSION] = "Incompatible file version",
    [IMPORT_SKIP_REASON.INVALID_FORMAT] = "Invalid asset format"
}

T.GROUPS = {
    FAVORITES = 'Favorites',
    RECENTS = 'Recents'
}
