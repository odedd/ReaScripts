-- @noindex
T = {}

T.SETTINGS = {
    MW_REVERSED = {
        LABEL = 'Reverse mousewheel',
        HINT = 'Use the mousewheel to control faders. Check to reverse its direction.',
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
        HINT = 'The order in which sends/recieves/hardware sends are shown in the main window.',
    }
}

    T.SETTINGS.LISTS = {
        [T.SETTINGS.SEND_TYPE_ORDER.LABEL] = {
            [SEND_TYPE.SEND] = 'SENDS',
            [SEND_TYPE.HW] = 'HARDWARE OUTPUTS',
            [SEND_TYPE.RECV] = 'RECIEVES',
        },
    }


