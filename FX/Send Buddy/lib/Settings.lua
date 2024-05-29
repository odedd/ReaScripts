-- @noindex

SM_Settings = OD_Settings:new({
    default = {
        -- Settings window
        mouseScrollReversed = true,
        followSelectedTrack = true,
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
        groupPriority = {
            ["VST3"] = 1,
            ["VST3i"] = 2,
            ["VST"] = 3,
            ["VSTi"] = 4,
            ["AU"] = 5,
            ["AUi"] = 6,
            ["JS"] = 7,
            ["CLAP"] = 8,
            ["CLAPi"] = 9,
            ["LV2"] = 10,
            ["LV2i"] = 11
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
