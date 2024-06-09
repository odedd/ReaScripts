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
        HINT = 'The order in which sends/receives/hardware sends are displayed.',
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
    VOL_TYPE = {
        LABEL = 'Volume and pan type',
        HINT = 'Volume/Pan type. "Match MCP/TCP faders" allows writing automation.',
    },
    SEND_TYPE_COLOR = {
        LABEL = '%s group',
        HINT = '%s group separator color.',
    },
    UI_SCALE = {
        LABEL = 'Zoom',
        HINT = 'Interface scale. Double click to enter manually.',
    }
}

T.SEND_TYPE_NAMES = {
    [SEND_TYPE.SEND] = { TITLE = 'Sends', PLURAL = 'Sends', SINGULAR = 'Send' },
    [SEND_TYPE.RECV] = { TITLE = 'Receives', PLURAL = 'Receives', SINGULAR = 'Receive' },
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
        [VOL_TYPE.UI] = 'Match MCP/TCP faders (Recommended)',
    },
    [T.SETTINGS.TEXT_MINIMIZATION_STYLE.LABEL] = {
        [MINIMIZATION_STYLE.PT] = 'Pro-Tools style',
        [MINIMIZATION_STYLE.TRIM] = 'Trim text to length',
    },
}

T.AUTO_MODE_DESCRIPTIONS = {
    [AUTO_MODE.TRACK] = { order = 0, label = 'Track', description = 'Follow track automation mode' },
    [AUTO_MODE.TRIM_READ] = { order = 1, label = 'Trim/Read', description = 'Envelopes are active but faders are all for trim' },
    [AUTO_MODE.READ] = { order = 2, label = 'Read', description = 'Play faders with armed envelopes' },
    [AUTO_MODE.TOUCH] = { order = 3, label = 'Touch', description = 'Record fader movements to armed envelopes' },
    [AUTO_MODE.LATCH] = { order = 4, label = 'Latch', description = 'Record fader movements after first movement' },
    [AUTO_MODE.LATCH_PREVIEW] = { order = 5, label = 'Latch Preview', description = 'Allow adjusting parameters but do not apply to envelopes' },
    [AUTO_MODE.WRITE] = { order = 6, label = 'Write', description = 'Record fader positions to armed envelopes' },
}

T.ERROR = {
    NO_DOCK = ([[
No previous dock found.

Please dock manually by dragging
the window to the dock of your choice.

After that, %s will remember
the dock position.]]):format(Scr.name)
}
