-- @noindex

PB_Settings = OD_Settings:new({
    default = {
        -- Settings window
        createInsideFolder = true,
        sendFolderName = 'FX Return Tracks',
        persistantMode = true,
        projectScanFolders = { '/Users/odeddavidov/Desktop' },
        showSideBar = false,
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
        -- Default group order using asset type class names (more robust than group names)
        -- Use SPECIAL_GROUPS constants for special groups
        groupOrder = {
            SPECIAL_GROUPS.RECENTS,   -- Recents (special group)
            SPECIAL_GROUPS.FAVORITES, -- Favorites (special group)
            SPECIAL_GROUPS.PLUGINS,   -- Placeholder for all FX types (VST3, AU, etc.)
            "FXChainAssetType",       -- FX Chains asset type
            "TrackAssetType",         -- Tracks asset type
            "TrackTemplateAssetType", -- Track Templates asset type
            "ActionAssetType",        -- Actions asset type
            "ProjectAssetType"        -- Projects asset type
        },
        groupVisibility = {
            [SPECIAL_GROUPS.RECENTS] = true,  -- Recents (special group)
            [SPECIAL_GROUPS.FAVORITES] = true, -- Favorites (special group)
            [SPECIAL_GROUPS.PLUGINS] = true,  -- Placeholder for all FX types (VST3, AU, etc.)
            ["FXChainAssetType"] = true,      -- FX Chains asset type
            ["TrackAssetType"] = true,        -- Tracks asset type
            ["TrackTemplateAssetType"] = true, -- Track Templates asset type
            ["ActionAssetType"] = true,       -- Actions asset type
            ["ProjectAssetType"] = true       -- Projects asset type
        },
        uiScale = 1,

        -- set In the UI
        sideBarWidth = 200,
        -- Internal
        minSideBarWidth = 140,
        lastDockId = nil,
        numberOfResultsThatRequireConfirmation = 10,
        numberOfTracksThatRequireConfirmation = 6,
        numberOfRecents = 5
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
