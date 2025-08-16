-- @noindex

PB_Settings = OD_Settings:new({
    default = {
        -- * SETTINGS WINDOW

        -- General Settings
        uiScale = 1,
        centerOnOpen = true,
        afterAction = AFTER_ACTION.CLOSE,
        sleepMode = false,
        resetFiltersOnWakeup = true,
        loadDefaultPreset = false,
        defaultPreset = nil,

        -- Ordering
        showOnlyHighestPriorityPlugin = true,
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
            ["QuickChainPresetAssetType"] = true
        },                                       -- Project Templates asset type
        showOnlyHighestPriorityVariant = true,
        variantMatchingOrder = {
            '%(?(stereo/%d%.%d)%)?',
            '%(?(mono/stereo)%)?',
            '%(?(stereo)%)?',
            '%(?(mono/%d%.%d)%)?',
            '%(?(mono)%)?',
            '%(?(dual)%)?',
            '%(?(%d%.%d/%d%.%d)%)?',
            '(upmix %dto%d)',
            '%((m)%)',
            '%((s)%)',
            '%(([^%)]-%->.-)%)',
            '%(([^%-%)]-ch)%)',
            '(5%.0)',
            '(5%.1)',
            '%((x86_64)%)',
            '%((x64)%)'
        },
        variantOrder = {
            '%(?(stereo)%)?',
            '%(?(mono)%)?',
            '%(?(mono/stereo)%)?',
            '%(?(stereo/%d%.%d)%)?',
            '%(?(mono/%d%.%d)%)?',
            '%(?(dual)%)?',
            '%(?(%d%.%d/%d%.%d)%)?',
            '(upmix %dto%d)',
            '%((m)%)',
            '%((s)%)',
            '%(([^%)]-%->.-)%)',
            '(5%.0)',
            '(5%.1)',
            '%(([^%-%)]-ch)%)',
            '%((x86_64)%)',
            '%((x64)%)'
        },
        variantVisibility = {
            ['%(?(stereo)%)?'] = true,
            ['%(?(mono)%)?'] = true,
            ['%(?(mono/stereo)%)?'] = true,
            ['%(?(stereo/%d%.%d)%)?'] = true,
            ['%(?(mono/%d%.%d)%)?'] = true,
            ['%(?(dual)%)?'] = true,
            ['%(?(%d%.%d/%d%.%d)%)?'] = true,
            ['(upmix %dto%d)'] = true,
            ['%((m)%)'] = true,
            ['%((s)%)'] = true,
            ['%(([^%)]-%->.-)%)'] = true,
            ['(5%.0)'] = true,
            ['(5%.1)'] = true,
            ['%(([^%-%)]-ch)%)'] = true,
            ['%((x86_64)%)'] = true,
            ['%((x64)%)'] = true,
        },
        -- Tags, Presets and Favorites
        tagDefaultColor = 5658198,

        -- Shortcuts
        shortcuts = {
            closeScript       = ImGui.Key_Escape,
            performAction     = ImGui.Key_Enter,
            toggleSearchMode  = ImGui.Key_Tab,
            hardCloseScript   = ImGui.Mod_Ctrl | ImGui.Key_Q,
            selectAllResults  = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_A,
            clearFilters      = ImGui.Mod_Ctrl | ImGui.Key_L,
            markFavorite      = ImGui.Mod_Ctrl | ImGui.Key_F,
            markHidden        = ImGui.Mod_Ctrl | ImGui.Key_H,
            runRandomResult   = ImGui.Mod_Ctrl | ImGui.Key_R,
            toggleAfterAction = ImGui.Mod_Ctrl | ImGui.Key_B,
            showSettings      = ImGui.Mod_Ctrl | ImGui.Key_Comma,
            showHelp          = ImGui.Mod_Ctrl | ImGui.Key_F1,
            toggleDock        = ImGui.Mod_Ctrl | ImGui.Key_D,
            toggleMinimalMode = ImGui.Mod_Ctrl | ImGui.Key_M,
            toggleSideBar     = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_S,
            toggleQuickChain  = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_K,
            addToQuickChain   = ImGui.Mod_Ctrl | ImGui.Key_K,
            clearQuickChain   = ImGui.Mod_Alt | ImGui.Key_K,
            quickTag          = ImGui.Mod_Ctrl | ImGui.Key_T,
            copyTags          = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_C,
            pasteTags         = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_V,
            syncTags          = ImGui.Mod_Ctrl | ImGui.Mod_Shift | ImGui.Key_Y,
            clearTags         = ImGui.Mod_Ctrl | ImGui.Mod_Alt | ImGui.Mod_Shift | ImGui.Key_X,
            clearRating       = ImGui.Mod_Alt | ImGui.Key_0,
            rate1             = ImGui.Mod_Alt | ImGui.Key_1,
            rate2             = ImGui.Mod_Alt | ImGui.Key_2,
            rate3             = ImGui.Mod_Alt | ImGui.Key_3,
            rate4             = ImGui.Mod_Alt | ImGui.Key_4,
            rate5             = ImGui.Mod_Alt | ImGui.Key_5,
        },

        -- Items Specific Settings
        recentlyAddedDays = 30,
        showFxUI = SHOW_FX_UI.FOLLOW_PREFERENCE,
        addInstrumentsAsInstrumentTracks = true,
        createSendsInsideFolder = false,
        sendFolderName = 'FX Return Tracks',
        overrideDefaultSendVolume = false,
        sendVolume = -12,
        showInvisibleTracks = true,
        showInvisibleTakeMarkers = false,
        projectScanFolders = {},
        scanRecentProjects = true,

        -- * SET IN THE UI
        minimalMode = false,
        showSideBar = true,
        sideBarShowFilters = true,
        sideBarShowRatingFilter = true,
        sideBarShowTags = true,
        sideBarWidth = 200,
        showQuickChain = false,
        quickChainWidth = 160,
        hideAllTags = false,
        hideRatings = false,
        sortByRating = true,

        -- * INTERNAL
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
