-- @noindex

-- ! CONSTANTS
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

APP_PAGE = {
    ['SEARCH'] = { width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None }
}


-- Load asset type IDs from manifest (with hardcoded IDs for stability)
ASSET_TYPE = {}
do
    -- Get the current script path to locate the manifest
    local info = debug.getinfo(1, "S")
    local scriptPath = info.source:match("@(.*[/\\])") or ""
    local assetTypesPath = scriptPath:gsub("lib[/\\]?$", "") .. "assetTypes/"
    local manifestPath = assetTypesPath .. "manifest.lua"
    
    -- Load manifest and assign IDs from explicit definitions
    local assetTypeDefinitions = dofile(manifestPath)
    for _, definition in ipairs(assetTypeDefinitions) do
        local className = definition.file:match("(.+)%.lua$")
        if className and definition.id ~= nil then
            ASSET_TYPE[className] = definition.id
        end
    end
end

FX_TYPE =
{
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
}

SEARCH_MODE = {
    MAIN = 0,
    FILTERS = 1
}

RESULT_CONTEXT = {
    ['MAIN'] = 0,
    ['ALT'] = 1,
    ['SHIFT'] = 2,
    ['CTRL'] = 3,
    ['DRAGGED_TO_TRACK'] = 4,
    ['DRAGGED_TO_BLANK'] = 5,
}

TAGS_ROOT_PARENT = -1

PLUGIN = {
    INTERNAL = { 'Video Processor', 'Container' },
}

-- Special group constants
-- Note: groupOrder in settings uses asset type class names (e.g., "ProjectAssetType") 
-- instead of group display names (e.g., "Projects") for better maintainability
SPECIAL_GROUPS = {
    FAVORITES = 'Favorites',
    PLUGINS = 'Plugins',  -- Placeholder for FX types in groupOrder
    RECENTS = 'Recents'         -- For future use
}

-- should be negative to differentiate them from regular assets
FILTER_TYPES = {
    PRESET = -1,
    TYPE = -2,
    FX_TYPE = -3,
    CATEGORY = -4,
    FOLDER = -5,
    DEVELOPER = -6,
    TAG = -7,
}

FILTER_MENU = {
        [FILTER_TYPES.PRESET] = {
        order = 0,
        items = {}
    },
    [FILTER_TYPES.TYPE] = {
        order = 2,
        allQuery = { type = 'all' },
        items = {} -- Will be populated dynamically by AssetTypeManager
    },
    [FILTER_TYPES.FX_TYPE] = {
        order = 3,
        allQuery = { fx_type = 'all' },
        items = {}
    },
    [FILTER_TYPES.FOLDER] = {
        order = 4,
        allQuery = { fxFolderId = 'all' },
        items = {} -- added in DataEngine.lua once folders are loaded
    },
    [FILTER_TYPES.CATEGORY] = {
        order = 5,
        allQuery = { fxCategory = 'all' },
        items = {} -- added in DataEngine.lua once folders are loaded
    },
    [FILTER_TYPES.DEVELOPER] = {
        order = 6,
        allQuery = { fxDeveloper = 'all' },
        items = {} -- added in DataEngine.lua once folders are loaded
    }
}
for i, fx_type_name in ipairs(FX_TYPE) do
    FILTER_MENU[FILTER_TYPES.FX_TYPE].items[fx_type_name] = {
        order = i,
        query = {
            fx_type = fx_type_name
        }
    }
end

-- Import failure reasons
IMPORT_SKIP_REASON = {
    ASSET_NOT_FOUND = 1,
    INCOMPATIBLE_VERSION = 2,
    INVALID_FORMAT = 3,
}

