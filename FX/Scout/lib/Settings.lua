-- @noindex

PB_Settings = OD_Settings:new({
    default = {
        -- Settings window
        createSendsInsideFolder = false,
        centerOnOpen = true,
        sendFolderName = 'FX Return Tracks',
        sleepMode = false,
        projectScanFolders = {},
        scanRecentProjects = true,
        showFxUI = SHOW_FX_UI.FOLLOW_PREFERENCE,
        afterAction = AFTER_ACTION.RESET_FILTERS,
        recentlyAddedDays = 30,
        addInstrumentsAsInstrumentTracks = true,
        minimalMode = false,
        overrideDefaultSendVolume = false,
        sendVolume = -12,
        showInvisibleTracks = false,
        showInvisibleTakeMarkers = false,
        tagDefaultColor = 5658198,
        hideAllTags = false,
        shortcuts = {
            markFavorite = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_F,
            closeScript = ImGui.Key_Escape,
            hardCloseScript = ImGui.Mod_Ctrl | ImGui.Key_Q,
            selectAllResults = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_A,
            clearFilters = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_L,
            runRandomResult = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_R,
            addToQuickChain = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_K,
            clearQuickChain = ImGui.Mod_Alt | ImGui.Key_K,
            toggleQuickChain = ImGui.Mod_Ctrl | ImGui.Key_K,
            toggleSideBar = ImGui.Mod_Ctrl | ImGui.Key_S,
            quickTag = ImGui.Mod_Ctrl | ImGui.Key_T,
            showSettings = ImGui.Mod_Ctrl | ImGui.Key_Comma,
            showHelp = ImGui.Mod_Ctrl | ImGui.Key_F1,
            toggleDock = ImGui.Mod_Ctrl | ImGui.Key_D,
            toggleMinimalMode = ImGui.Mod_Ctrl | ImGui.Key_M,
        },
        fxTypeVisibility = {
            ['Internal'] = true,
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
            SPECIAL_GROUPS.RECENTS,      -- Recents (special group)
            SPECIAL_GROUPS.FAVORITES,    -- Favorites (special group)
            SPECIAL_GROUPS.PLUGINS,      -- Placeholder for all FX types (VST3, AU, etc.)
            "QuickChainPresetAssetType", -- QuickChain asset type
            "FXChainAssetType",          -- FX Chains asset type
            "TrackTemplateAssetType",    -- Track Templates asset type
            "ProjectTemplateAssetType",  -- Project Templates asset type
            "TrackAssetType",            -- Tracks asset type
            "TakeAssetType",             -- Takes asset type
            "MarkerAssetType",           -- Markers asset type
            "RegionAssetType",           -- Regions asset type
            "TakeMarkerAssetType",       -- Take Markers asset type
            "ProjectAssetType",          -- Projects asset type
            "ActionAssetType",           -- Actions asset type
        },
        groupVisibility = {
            [SPECIAL_GROUPS.RECENTS] = true,     -- Recents (special group)
            [SPECIAL_GROUPS.FAVORITES] = true,   -- Favorites (special group)
            [SPECIAL_GROUPS.PLUGINS] = true,     -- Placeholder for all FX types (VST3, AU, etc.)
            ["FXChainAssetType"] = true,         -- FX Chains asset type
            ["TrackAssetType"] = true,           -- Tracks asset type
            ["TakeAssetType"] = true,            -- Takes asset type
            ["TrackTemplateAssetType"] = true,   -- Track Templates asset type
            ["ActionAssetType"] = true,          -- Actions asset type
            ["ProjectAssetType"] = true,         -- Projects asset type
            ["MarkerAssetType"] = true,          -- Markers asset type
            ["TakeMarkerAssetType"] = true,      -- Take Markers asset type
            ["RegionAssetType"] = true,          -- Markers asset type
            ["ProjectTemplateAssetType"] = true, -- Project Templates asset type
            ["QuickChainPresetAssetType"] = true -- Project Templates asset type
        },
        showOnlyHighestPriorityVariant = false,
        variantOrder = {
            '%(?(stereo)%)?',
            '%(?(mono)%)?',
            '%(?(mono/stereo)%)?',
            '%(?(stereo/%d%.%d)%)?',
            '%(?(mono/%d%.%d)%)?',
            '%(?(%d%.%d/%d%.%d)%)?',
            '(upmix %dto%d)',
            '%((m)%)',
            '%((s)%)',
            '%((.-%->.+)%)',
            '(5%.0)',
            '(5%.1)',
            '%((x86_64)%)',
            '%((x64)%)' },
        variantVisibility = {
            ['%(?(stereo)%)?'] = true,
            ['%(?(mono)%)?'] = true,
            ['%(?(mono/stereo)%)?'] = true,
            ['%(?(stereo/%d%.%d)%)?'] = true,
            ['%(?(mono/%d%.%d)%)?'] = true,
            ['%(?(%d%.%d/%d%.%d)%)?'] = true,
            ['(upmix %dto%d)'] = true,
            ['%((m)%)'] = true,
            ['%((s)%)'] = true,
            ['%((.-%->.+)%)'] = true,
            ['(5%.0)'] = true,
            ['(5%.1)'] = true,
            ['%((x86_64)%)'] = true,
            ['%((x64)%)'] = true,
        },
        uiScale = 1,

        -- set In the UI
        sideBarWidth = 200,
        showSideBar = true,
        quickChainWidth = 160,
        showQuickChain = false,
        -- Internal
        minSideBarWidth = 140,
        minQuickChainWidth = 140,
        lastDockId = nil,
        lastDockedState = false,
        numberOfResultsThatRequireConfirmation = 10,
        numberOfTracksThatRequireConfirmation = 6,
        numberOfMediaItemsThatRequireConfirmation = 6,
        numberOfRecents = 5,
        welcomeScreenShown = false
    },
    initial = {
        projectScanFolders = {},
    },
    dfsetfile = Scr.dfsetfile
})

function PB_Settings.shortCutToKeyChord(shortcut)
    if shortcut == nil then return 0 end
    return shortcut
    -- return OD_GetImGuiKeyCode(ImGui, shortcut.key)|
    --     (shortcut.shift and ImGui.Mod_Shift or 0) |
    --     (shortcut.ctrl and ImGui.Mod_Ctrl or 0) |
    --     (shortcut.macCtrl and ImGui.Mod_Super or 0) |
    -- (shortcut.alt and ImGui.Mod_Alt or 0)
end

function PB_Settings:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- * local
