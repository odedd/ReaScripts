-- @noindex
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

-- ! CONSTANTS
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

APP_PAGE = {
    ['SEARCH_FX'] = { width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None }
}


ASSETS = {
    ['TRACK'] = 0,
    ['PLUGIN'] = 1,
    ['FX_CHAIN'] = 2,
    ['TRACK_TEMPLATE'] = 3,
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
ALL_TRACKS_GROUP = 'All tracks'

FILTER_MENU = {
    ['Type'] = {
        order = 1,
        allQuery = { type = 'all' },
        items = {
            ['Track Templates'] = { order = 2, query = { type = ASSETS.TRACK_TEMPLATE } },
            ['FX Chains'] = { order = 3, query = { type = ASSETS.FX_CHAIN } },
            ['Plugins'] = { order = 1, query = { type = ASSETS.PLUGIN } },
        }
    },
    ['Plugin Type'] = {
        order = 2,
        allQuery = { fx_type = 'all' },
        items = {}
    },
    ['Folders'] = {
        order = 3,
        allQuery = { fxFolderId = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    },
    ['Categories'] = {
        order = 4,
        allQuery = { fxCategory = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    },
    ['Developers'] = {
        order = 5,
        allQuery = { fxDeveloper = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    }
}
for i, fx_type_name in ipairs(FX_TYPE) do
    FILTER_MENU['Plugin Type'].items[fx_type_name] = {
        order = i,
        query = {
            fx_type = fx_type_name
        }
    }
end
