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
    FOLLOW_SELECTED_TRACK = {
        LABEL = 'Follow selected track',
        HINT = ('Change track in %s when a new track is selected.'):format(Scr.name),
    },
    FX_TYPE_ORDER = {
        LABEL = 'FX type priority',
        HINT = 'The order in which FX are displayed in the search window.',
    },
    SEND_TYPE_ORDER = {
        LABEL = 'Send type order',
        HINT = 'The order in which sends/recieves/hardware sends are displayed.',
    },
    SHORTCUTS = {
        NEW_SEND = {
            LABEL = 'New send',
            HINT = 'Shortcut to create a new send.',
        },
        NEW_RECV = {
            LABEL = 'New recieve',
            HINT = 'Shortcut to create a new recieve.',
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
    VOL_TYPE = {
        LABEL = 'Volume and pan type',
        HINT = 'Volume/Pan controls used. "Match UI" allows writing automation.',
    },
}

T.SEND_TYPE_NAMES = {
    [SEND_TYPE.SEND] = { TITLE = 'Sends', PLURAL = 'Sends', SINGULAR = 'Send' },
    [SEND_TYPE.RECV] = { TITLE = 'Recieves', PLURAL = 'Recieves', SINGULAR = 'Recieve' },
    [SEND_TYPE.HW] = { TITLE = 'HARDWARE', PLURAL = 'Hardware outputs', SINGULAR = 'Hardware output' },
}

T.SETTINGS.LISTS = {
    [T.SETTINGS.SEND_TYPE_ORDER.LABEL] = {
        [SEND_TYPE.SEND] = (T.SEND_TYPE_NAMES[SEND_TYPE.SEND].PLURAL):upper(),
        [SEND_TYPE.HW] = (T.SEND_TYPE_NAMES[SEND_TYPE.HW].PLURAL):upper(),
        [SEND_TYPE.RECV] = (T.SEND_TYPE_NAMES[SEND_TYPE.RECV].PLURAL):upper(),
    },
    [T.SETTINGS.VOL_TYPE.LABEL] = {
        [VOL_TYPE.TRIM] = 'Trim',
        [VOL_TYPE.UI] = 'Match UI (Recommended)',
    },
}


T.ERROR = {
    NO_DOCK = ([[
No previous dock found.

Please dock manually by dragging
the window to the dock of your choice.

After that, %s will remember
the dock position.]]):format(Scr.name)
}
