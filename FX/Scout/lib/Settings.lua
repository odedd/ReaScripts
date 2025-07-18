-- @noindex

PB_Settings = OD_Settings:new({
    default = {
        -- Settings window
        mouseScrollReversed = false,
        followSelectedTrack = true,
        createInsideFolder = true,
        sendFolderName = 'FX Return Tracks',
        persistantMode = true,
        textMinimizationStyle = MINIMIZATION_STYLE.PT,
        shortcuts = {
            markFavorite = {
                key = OD_KEYCODES.F,
                ctrl = true,
                shift = true,
                alt = false,
                macCtrl = false
            },
            resetFilters = {
                key = OD_KEYCODES.R,
                ctrl = false,
                shift = false,
                alt = true,
                macCtrl = false
            },
            closeScript = {
                key = OD_KEYCODES.ESCAPE,
                ctrl = false,
                shift = false,
                alt = false,
                macCtrl = false
            },
            hardCloseScript = {
                key = OD_KEYCODES.Q,
                ctrl = false,
                shift = false,
                alt = true,
                macCtrl = false
            },
            selectAllResults = {
                key = OD_KEYCODES.A,
                ctrl = true,
                shift = true,
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

        -- set In the UI
        filterPanelWidth = 200,
        minFilterPanelWidth = 140,
        -- Internal
        lastDockId = nil,
    },
    dfsetfile = Scr.dfsetfile
})

function PB_Settings:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- * local
