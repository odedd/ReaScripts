-- @noindex
T = {}

T.SETTINGS = {
    MW_REVERSED = {
        LABEL = 'Reverse mousewheel',
        HINT = 'Mousewheel is used to control faders. Check to reverse its direction.',
    },
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
    TEXT_MINIMIZATION_STYLE = {
        LABEL = 'Text minimization style',
        HINT = 'Minimization style for track/plugin/hw output names.',
    },
    SHORTCUTS = {
        CLOSE_SCRIPT = {
            LABEL = 'Close script',
            HINT = 'Shortcut to close script.',
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
    }
}

T.SETTINGS.LISTS = {
    [T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL] = {
        PT = 'Pro-Tools style',
        TRIM = 'Trim text to length',
    },
}
T.SEARCH_WINDOW = {
    SEARCH_HINT = {
        [SEARCH_MODE.MAIN] = 'Searching items. Press Tab to search filters',
        [SEARCH_MODE.FILTERS] = 'Searching filters. Press Tab to search items',
    }
}
T.FILTER_NAMES = {
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
