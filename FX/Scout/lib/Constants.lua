-- @noindex

-- ! CONSTANTS
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

APP_PAGE = {
    ['SEARCH'] = { width = 260, height = 409, minHeight = 309, windowFlags = ImGui.WindowFlags_None }
}

PLUGIN = {
    VENDOR_ALIASES = {
        -- some vendors have different names in different plugin types / old plugins but are actually the same developer
        -- [''] = { '', '' },
        ['Steinberg'] = { 'Steinberg', 'Steinberg Media Technologies' },
        ['iZotope'] = { 'iZotope, Inc.', 'iZotope' },
        ['Plogue Art et Technologie'] = { 'Plogue Art et Technologie', 'Plogue Art et Technologie, Inc' },
        ['Denise Audio'] = { 'Denise', 'Denise Audio' },
        ['Universal Audio'] = { 'Universal Audio, Inc.', 'Universal Audio', 'Universal Audio (UADx)' },
        ['Native Instruments'] = { 'Native Instruments GmbH', 'Native Instruments' },
    }
}

-- build reverse lookup table
PLUGIN.ALIASES_TO_VENDORS = {}
for mainAlias, vendors in pairs(PLUGIN.VENDOR_ALIASES) do
    for _, vendor in ipairs(vendors) do
        PLUGIN.ALIASES_TO_VENDORS[vendor] = mainAlias
    end
end

YIELD_FREQUENCY = 10

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
    FILTERS = 1,
    SEND_BUDDY = 2
}

RESULT_CONTEXT = {
    ['NONE'] = 0,
    ['IGNORE_KEYS'] = 1,
    ['KEYBOARD'] = 2,
    ['MOUSE_CLICK'] = 4,
    ['MOUSE_DOUBLE_CLICK'] = 8,
    ['DRAGGED_TO_OBJECT'] = 16,
    ['DRAGGED_TO_BLANK'] = 32,
    ['QUICK_CHAIN'] = 64,
}

SHOW_FX_UI = {
    FOLLOW_PREFERENCE = 0,
    OPEN = 1,
    DONT_OPEN = 2
}

AFTER_ACTION = {
    CLOSE = 0,
    CLEAR_TEXT = 1,
    DO_NOTHING = 2
}

EXPORT_ACTION_TYPE = {
    APPLY_FILTER = 0,
    RUN_RANDOM = 1,
    QUICK_CHAIN = 2
}

RATING_FILTER_TYPE = {
    EQUAL = 0,
    EQUAL_OR_MORE = 1,
    EQUAL_OR_LESS = 2,
}

MAGIC_WORD_TYPE = {
    PRESET = 0,
    QUICK_CHAIN = 1,
    FILTER = 2,
}

EXPORT_ACTIONS = {
    [EXPORT_ACTION_TYPE.APPLY_FILTER] = 'APPLY_FILTER',
    [EXPORT_ACTION_TYPE.RUN_RANDOM] = 'RUN_RANDOM',
    [EXPORT_ACTION_TYPE.QUICK_CHAIN] = 'QUICK_CHAIN',
}

TAGS_ROOT_PARENT = -1

SETTINGS_SECTIONS = {
    GENERAL = {order = 1},
    ITEM = {order = 2},
    ORDERING = {order = 3},
    SHORTCUTS = {order = 4},
    USER_DATA = {order = 5}
}
-- Special group constants
-- Note: groupOrder in settings uses asset type class names (e.g., "ProjectAssetType")
-- instead of group display names (e.g., "Projects") for better maintainability
SPECIAL_GROUPS = {
    FAVORITES = 'Favorites',
    PLUGINS = 'PluginAssetType', -- Placeholder for FX types in groupOrder. Needs to be equal to the plugin asset type to allow hiding it in results
    RECENTS = 'Recents'          -- For future use
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
    OTHER = -8,
    RATING = -9,
}

FILTER_ICONS = {
    [FILTER_TYPES.PRESET] = ICONS.BRIEFCASE,
    [FILTER_TYPES.TYPE] = ICONS.QUESTION,
    [FILTER_TYPES.FX_TYPE] = ICONS.SUBFOLDER,
    [FILTER_TYPES.CATEGORY] = ICONS.BOX,
    [FILTER_TYPES.FOLDER] = ICONS.FOLDER,
    [FILTER_TYPES.DEVELOPER] = ICONS.COMPUTER,
    [FILTER_TYPES.TAG] = ICONS.TAG,
    [FILTER_TYPES.OTHER] = ICONS.GOGGLES,
    [FILTER_TYPES.RATING] = ICONS.STAR,
}

FILTER_MENU = {
    [FILTER_TYPES.PRESET] = {
        order = 1,
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
    },
    [FILTER_TYPES.OTHER] = {
        order = 7,
        items = {
            ['Tagged'] = {
                order = 1,
                allQuery = { tagged = 'all' },
                query = { tagged = true }
            },
            ['Untagged'] = {
                order = 2,
                allQuery = { untagged = 'all' },
                query = { untagged = true }
            },
            ['Hidden'] = {
                order = 3,
                allQuery = { hidden = 'all' },
                query = { hidden = true }
            },
            ['Recently Added'] = {
                order = 4,
                allQuery = { recentlyAdded = 'all' },
                query = { recentlyAdded = true }
            }
        } -- added in DataEngine.lua once folders are loaded
    },
    [FILTER_TYPES.RATING] = {
        order = 0,
        hide = true,
        allQuery = { rating = 'all' },
        items = {

        }
    }
}

-- FX type filter menu will be populated dynamically by DataEngine based on fxTypeVisibility settings

-- Import failure reasons
IMPORT_SKIP_REASON = {
    ASSET_NOT_FOUND = 1,
    INCOMPATIBLE_VERSION = 2,
    INVALID_FORMAT = 3,
}

EXPORTED_ACTION = [[
local r = reaper
local context = '$context'
local script_name = '$scriptname'
local cmd = '$cmd'

function getScriptId(script_name)
    local file = io.open(r.GetResourcePath().."/".."reaper-kb.ini")
    if not file then return "" end
    local content = file:read("*a")
    file:close()
    local santizedSn = script_name:gsub("([^%w])", "%%%1")
    if content:find(santizedSn) then
        return content:match('[^\r\n].+(RS.+) "Custom: '..santizedSn)
    end
end

local cmdId = getScriptId(script_name)

if cmdId then
    local intId = r.NamedCommandLookup('_'..cmdId)
    if intId ~= 0 then r.Main_OnCommand(intId,0) end
    r.SetExtState(context, 'EXTERNAL_COMMAND',cmd, false)
else
    r.MB(script_name..' not installed', script_name,0)
end]]
