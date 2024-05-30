-- @noindex

SM_Settings = OD_Settings:new({ --TODO proper defaults
    default = {
        -- Settings window
        mouseScrollReversed = true,
        followSelectedTrack = false,
        createInsideFolder = true,
        sendFolderName = 'FX BUS',
        sendTypeVisibility = {
            [SEND_TYPE.SEND] = true,
            [SEND_TYPE.RECV] = true,
            [SEND_TYPE.HW] = true
        },
        sendTypeOrder = {
            SEND_TYPE.SEND,
            SEND_TYPE.HW,
            SEND_TYPE.RECV,
        },
        shortcuts = {
            addSend = {
                key = OD_KEYCODES.S,
                ctrl = false,
                shift = false,
                alt = true,
                macCtrl = false
            },
            addRecv = {
                key = OD_KEYCODES.R,
                ctrl = false,
                shift = false,
                alt = true,
                macCtrl = false
            },
            addHW = {
                key = OD_KEYCODES.H,
                ctrl = false,
                shift = false,
                alt = true,
                macCtrl = false
            },
            markFavorite = {
                key = OD_KEYCODES.F,
                ctrl = true,
                shift = false,
                alt = true,
                macCtrl = false
            }
        },
        fxTypeVisibility = {
            ['VST3'] = true,
            ['VST3i'] = true,
            ['VST'] = true,
            ['VSTi'] = true,
            ['AU'] = true,
            ['AUi'] = true,
            ['JS'] = true,
            ['CLAP'] = true,
            ['CLAPi'] = true,
            ['LV2'] = true,
            ['LV2i'] = true
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
