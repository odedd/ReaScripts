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
    ['NONE'] = 0,
    ['KEYBOARD'] = 1,
    ['MOUSE_CLICK'] = 2,
    ['MOUSE_DOUBLE_CLICK'] = 4,
    ['DRAGGED_TO_OBJECT'] = 8,
    ['DRAGGED_TO_BLANK'] = 16,
}

SHOW_FX_UI = {
    FOLLOW_PREFERENCE = 0,
    OPEN = 1,
    DONT_OPEN = 2
}

SHOW_FX_UI_DESCRIPTIONS = {
    [SHOW_FX_UI.FOLLOW_PREFERENCE] = 'Follow Reaper\'s preferences',
    [SHOW_FX_UI.OPEN] = 'Always open',
    [SHOW_FX_UI.DONT_OPEN] = 'Never open'
}

for i = 0, #SHOW_FX_UI_DESCRIPTIONS do
    SHOW_FX_UI_LIST = (SHOW_FX_UI_LIST or '') .. SHOW_FX_UI_DESCRIPTIONS[i] .. '\0'
end


TAGS_ROOT_PARENT = -1

PLUGIN = {
    INTERNAL = { 'Video Processor', 'Container' },
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
}

FILTER_ICONS = {
    [FILTER_TYPES.PRESET] = ICONS.BRIEFCASE,
    [FILTER_TYPES.TYPE] = ICONS.QUESTION,
    [FILTER_TYPES.FX_TYPE] = ICONS.SUBFOLDER,
    [FILTER_TYPES.CATEGORY] = ICONS.BOX,
    [FILTER_TYPES.FOLDER] = ICONS.FOLDER,
    [FILTER_TYPES.DEVELOPER] = ICONS.COMPUTER,
    [FILTER_TYPES.TAG] = ICONS.TAG,
    [FILTER_TYPES.OTHER] = ICONS.STAR,
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
        order = 6,
        allQuery = { untagged = 'all' },
        items = {
            ['Untagged'] = {
                order = 1,
                query = { untagged = true }
            }
        } -- added in DataEngine.lua once folders are loaded
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
    if r.GetExtState(context, 'defer') ~= '1' then
        local intId = r.NamedCommandLookup('_'..cmdId)
        if intId ~= 0 then r.Main_OnCommand(intId,0) end
    end
    r.SetExtState(context, 'EXTERNAL_COMMAND',cmd, false)
else
    r.MB(script_name..' not installed', script_name,0)
end]]
