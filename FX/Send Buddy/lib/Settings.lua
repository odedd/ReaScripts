-- @noindex

SM_Settings = OD_Settings:new({
    default = {
        -- Settings window
        mouseScrollReversed = false,
        followSelectedTrack = true,
        createInsideFolder = true,
        sendFolderName = 'FX Return Tracks',
        volType = VOL_TYPE.UI,
        textMinimizationStyle = MINIMIZATION_STYLE.PT,
        sendTypeVisibility = {
            [SEND_TYPE.SEND] = true,
            [SEND_TYPE.RECV] = true,
            [SEND_TYPE.HW] = false
        },
        sendTypeOrder = {
            SEND_TYPE.HW,
            SEND_TYPE.SEND,
            SEND_TYPE.RECV,
        },
        sendTypeColor = {
            [SEND_TYPE.SEND] = 0x371f23FF,
            [SEND_TYPE.RECV] = 0x371f23FF,
            [SEND_TYPE.HW] = 0x371f23FF
        },
        shortcuts = {
            addSend = {
                key = OD_KEYCODES.S,
                ctrl = false,
                shift = true,
                alt = true,
                macCtrl = false
            },
            addRecv = {
                key = OD_KEYCODES.R,
                ctrl = false,
                shift = true,
                alt = true,
                macCtrl = false
            },
            addHW = {
                key = OD_KEYCODES.H,
                ctrl = false,
                shift = true,
                alt = true,
                macCtrl = false
            },
            markFavorite = {
                key = OD_KEYCODES.F,
                ctrl = true,
                shift = true,
                alt = false,
                macCtrl = false
            },
            closeScript = {
                key = OD_KEYCODES.ESCAPE,
                ctrl = false,
                shift = false,
                alt = false,
                macCtrl = false
            }
        },
        fxTypeVisibility = {
            ['VST3'] = true,
            ['VST3i'] = false,
            ['VST'] = true,
            ['VSTi'] = false,
            ['AU'] = true,
            ['AUi'] = false,
            ['JS'] = true,
            ['CLAP'] = true,
            ['CLAPi'] = false,
            ['LV2'] = true,
            ['LV2i'] = false
        },
        fxTypeOrder = {
            "VST3",
            "VST3i",
            "VST",
            "VSTi",
            "AU",
            "AUi",
            "JS",
            "CLAP",
            "CLAPi",
            "LV2",
            "LV2i"
        },
        uiScale = 1,

        -- Defineable in GUI
        favorites = {},
        sendWidth = 60,
        maxNumInserts = 1, -- changes automatically when resizing

        -- Internal
        lastDockId = nil,
        -- Permanent settings
        minSendVol = -100,
        maxSendVol = 12,
        scaleFactor = 2, -- fader scale factor above scaleLevel
        scaleLevel = -20,
    },
    dfsetfile = Scr.dfsetfile
})

function SM_Settings:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- * local
