-- @noindex
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

-- ! CONSTANTS
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

APP_PAGE = {
    ['SEARCH'] = { width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None }
}


ASSETS = {
    ['TRACK'] = 0,
    ['PLUGIN'] = 1,
    ['FX_CHAIN'] = 2,
    ['TRACK_TEMPLATE'] = 3,
    ['ACTION'] = 4,
    ['PROJECT'] = 5,
}

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
SPECIAL_GROUPS = {
    FAVORITES = 'Favorites',
    PLUGINS = 'Plugins',  -- Placeholder for FX types in groupOrder
    RECENTS = 'Recents'         -- For future use
}

FILTER_TYPES = {
    TYPE = 1,
    FX_TYPE = 2,
    CATEGORY = 3,
    FOLDER = 4,
    DEVELOPER = 5,
    TAG = 6,
}

FILTER_MENU = {
    [FILTER_TYPES.TYPE] = {
        order = 1,
        allQuery = { type = 'all' },
        items = {} -- Will be populated dynamically by AssetTypeManager
    },
    [FILTER_TYPES.FX_TYPE] = {
        order = 2,
        allQuery = { fx_type = 'all' },
        items = {}
    },
    [FILTER_TYPES.FOLDER] = {
        order = 3,
        allQuery = { fxFolderId = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    },
    [FILTER_TYPES.CATEGORY] = {
        order = 4,
        allQuery = { fxCategory = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    },
    [FILTER_TYPES.DEVELOPER] = {
        order = 5,
        allQuery = { fxDeveloper = 'all' },
        items = {} -- added in Db.lua once folders are loaded
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

