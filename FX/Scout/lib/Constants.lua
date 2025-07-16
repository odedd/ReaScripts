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
    ['DRAGGED_TO_TRACK'] = 2,
    ['DRAGGED_TO_BLANK'] = 3,
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

FILTER_MENU_TITLES = {
    TYPE = 'Search For',
    FX_TYPE = 'FX Type',
    FOLDER = 'Folder',
    CATEGORY = 'Category',
    DEVELOPER = 'Developer',
    TAGS = 'Tag'
}


FILTER_MENU = {
    [FILTER_MENU_TITLES.TYPE] = {
        order = 1,
        allQuery = { type = 'all' },
        items = {
            ['Track Templates'] = { order = 2, query = { type = ASSETS.TRACK_TEMPLATE } },
            ['FX Chains'] = { order = 3, query = { type = ASSETS.FX_CHAIN } },
            ['FX'] = { order = 1, query = { type = ASSETS.PLUGIN } },
        }
    },
    [FILTER_MENU_TITLES.FX_TYPE] = {
        order = 2,
        allQuery = { fx_type = 'all' },
        items = {}
    },
    [FILTER_MENU_TITLES.FOLDER] = {
        order = 3,
        allQuery = { fxFolderId = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    },
    [FILTER_MENU_TITLES.CATEGORY] = {
        order = 4,
        allQuery = { fxCategory = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    },
    [FILTER_MENU_TITLES.DEVELOPER] = {
        order = 5,
        allQuery = { fxDeveloper = 'all' },
        items = {} -- added in Db.lua once folders are loaded
    }
}
for i, fx_type_name in ipairs(FX_TYPE) do
    FILTER_MENU[FILTER_MENU_TITLES.FX_TYPE].items[fx_type_name] = {
        order = i,
        query = {
            fx_type = fx_type_name
        }
    }
end

FILTER_CAPSULE_TYPES = {
    FILTER_MENU_TITLES.TYPE,
    FILTER_MENU_TITLES.FX_TYPE,
    FILTER_MENU_TITLES.CATEGORY,
    FILTER_MENU_TITLES.FOLDER,
    FILTER_MENU_TITLES.DEVELOPER,
    FILTER_MENU_TITLES.TAGS,
}