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
        HINT = 'Name of the folder track. If one does not exist, it will be created when adding sends.',
    },
    FOLLOW_SELECTED_TRACK = {
        LABEL = 'Follow selected track',
        HINT = ('Change track in %s when a new track is selected.'):format(Scr.name),
    },
    FX_TYPE_ORDER = {
        LABEL = 'FX type priority',
        HINT = 'The order in which FX are displayed in the FX list.',
    },
    SEND_TYPE_ORDER = {
        LABEL = 'Send type order',
        HINT = 'The order in which sends/recieves/hardware sends are shown.',
    }
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
}


T.ERROR = {
    NO_DOCK = ([[
No previous dock found.

Please dock manually by dragging
the window to the dock of your choice.

After that, %s will remember
the dock position.]]):format(Scr.name)
}
