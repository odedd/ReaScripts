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
RECEIVES_GROUP = 'Tracks with receives'
TRACKS_GROUP = 'Other tracks'
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
            ['Plugin'] = {
                order = 1, 
                submenu = {
                    allQuery = { type=ASSETS.PLUGIN, fx_type = nil },
                    items = {}
                },
            }
        }
    }
}
for i, fx_type_name in ipairs(FX_TYPE) do
    FILTER_MENU['Type'].items['Plugin'].submenu.items[fx_type_name] = { 
        order = i,
        query = {
            type = ASSETS.PLUGIN, fx_type = fx_type_name 
        } }
end
