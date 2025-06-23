-- @noindex
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
ImGui = require 'imgui' '0.9.1'

-- ! CONSTANTS
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

APP_PAGE = {
    ['SEARCH_FX'] = {width = 900, height = 409, minHeight = 409, windowFlags = ImGui.WindowFlags_None}
}

ICONS = {
    ['DOCK_DOWN'] = 'D',
    ['UNDOCK'] = 'E',
    ['ARROW_LEFT'] = 'F',
    ['GEAR'] = 'G',
    ['HEADPHONES'] = 'H',
    ['LEFT'] = 'L',
    ['MONEY'] = 'M',
    ['POLARITY'] = 'O',
    ['PLUS'] = 'P',
    ['RIGHT'] = 'R',
    ['STAR'] = 'S',
    ['TRASH'] = 'T',
    ['UNDO'] = 'U',
    ['ENVELOPE'] = 'V',
    ['ARROW_RIGHT'] = 'W',
    ['CLOSE'] = 'X',
    ['STEREO'] = 'Y',
    ['MONO'] = 'Z'
}

ASSETS = {
    ['TRACK'] = 0,
    ['PLUGIN'] = 1,
    ['FX_CHAIN'] = 2,
    ['TRACK_TEMPLATE'] = 3,
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