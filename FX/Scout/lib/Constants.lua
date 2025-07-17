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

MINIMIZATION_STYLE = {
    ['PT'] = 0,
    ['TRIM'] = 1,
}

PLUGIN = {
    INTERNAL = { 'Video Processor', 'Container' },
}
FAVORITE_GROUP = 'Favorite'
TRACKS_GROUP = 'Tracks'
TRACK_TEMPLATES_GROUP = 'Track Templates'
FX_CHAINS_GROUP = 'FX Chains'
ACTIONS_GROUP = 'Actions'
ALL_TRACKS_GROUP = 'All tracks'

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
        items = {
            ['Track Templates'] = { order = 2, query = { type = ASSETS.TRACK_TEMPLATE } },
            ['FX Chains'] = { order = 3, query = { type = ASSETS.FX_CHAIN } },
            ['FX'] = { order = 1, query = { type = ASSETS.PLUGIN } },
            ['TRACKS'] = { order = 1, query = { type = ASSETS.TRACK } },
        }
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

