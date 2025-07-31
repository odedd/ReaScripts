-- @noindex

PB_Settings = OD_Settings:new({
    default = {
        -- Settings window
        createSendsInsideFolder = true,
        sendFolderName = 'FX Return Tracks',
        sleepMode = false,
        projectScanFolders = {},
        showFxUI = SHOW_FX_UI.FOLLOW_PREFERENCE,
        closeAfterExecute = true,
        recentlyAddedDays = 30,
        shortcuts = {
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
            },
            hardCloseScript = {
                key = OD_KEYCODES.Q,
                ctrl = true,
                shift = true,
                alt = false,
                macCtrl = false
            },
            selectAllResults = {
                key = OD_KEYCODES.A,
                ctrl = true,
                shift = true,
                alt = false,
                macCtrl = false
            },
            runRandomResult = {
                key = OD_KEYCODES.R,
                ctrl = true,
                shift = true,
                alt = false,
                macCtrl = false
            }
        },
        fxTypeVisibility = {
            ['Internal'] = true,
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
            "Internal",
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
        showOnlyHighestPriorityPlugin = true,
        groupOrder = {
            SPECIAL_GROUPS.RECENTS,     -- Recents (special group)
            SPECIAL_GROUPS.FAVORITES,   -- Favorites (special group)
            SPECIAL_GROUPS.PLUGINS,     -- Placeholder for all FX types (VST3, AU, etc.)
            "FXChainAssetType",         -- FX Chains asset type
            "TrackTemplateAssetType",   -- Track Templates asset type
            "ProjectTemplateAssetType", -- Project Templates asset type
            "TrackAssetType",           -- Tracks asset type
            "TakeAssetType",            -- Takes asset type
            "MarkerAssetType",          -- Markers asset type
            "ProjectAssetType",         -- Projects asset type
            "ActionAssetType",          -- Actions asset type
        },
        groupVisibility = {
            [SPECIAL_GROUPS.RECENTS] = true,    -- Recents (special group)
            [SPECIAL_GROUPS.FAVORITES] = true,  -- Favorites (special group)
            [SPECIAL_GROUPS.PLUGINS] = true,    -- Placeholder for all FX types (VST3, AU, etc.)
            ["FXChainAssetType"] = true,        -- FX Chains asset type
            ["TrackAssetType"] = true,          -- Tracks asset type
            ["TakeAssetType"] = true,           -- Takes asset type
            ["TrackTemplateAssetType"] = true,  -- Track Templates asset type
            ["ActionAssetType"] = true,         -- Actions asset type
            ["ProjectAssetType"] = true,        -- Projects asset type
            ["MarkerAssetType"] = true,         -- Markers asset type
            ["ProjectTemplateAssetType"] = true -- Project Templates asset type
        },
        uiScale = 1,

        -- set In the UI
        sideBarWidth = 200,
        showSideBar = true,
        -- Internal
        minSideBarWidth = 140,
        lastDockId = nil,
        numberOfResultsThatRequireConfirmation = 10,
        numberOfTracksThatRequireConfirmation = 6,
        numberOfMediaItemsThatRequireConfirmation = 6,
        numberOfRecents = 5,
        welcomeScreenShown = false
    },
    initial = {
        projectScanFolders = { '/Users/odeddavidov/Desktop' },
    },
    dfsetfile = Scr.dfsetfile
})

function PB_Settings.shortCutToKeyChord(shortcut)
    if shortcut == nil then return 0 end
    return OD_GetImGuiKeyCode(ImGui, shortcut.key)|
        (shortcut.shift and ImGui.Mod_Shift or 0) |
        (shortcut.ctrl and ImGui.Mod_Ctrl or 0) |
        (shortcut.macCtrl and ImGui.Mod_Super or 0) |
        (shortcut.alt and ImGui.Mod_Alt or 0)
end

function PB_Settings:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- * local
