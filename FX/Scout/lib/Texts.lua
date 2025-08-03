-- @noindex
T = {}

T.EXPORT_ACTION_DIALOG = {
    INFO = 'Create a Reaper action that will either open ' ..
        Scr.name ..
        ' with the saved filter, or randomly select one of the filter\'s results and run it.'
    ,
    ACTION_TYPE = {
        LABEL = 'Action',
        HINT = 'Select what the action should do.',
    },
    NAME = {
        LABEL = 'Name',
        HINT = 'Will be prefixed by \'' .. Scr.no_ext .. '\'.',
    },
    EXPORT = {
        LABEL = '',
        BUTTON = 'Export as Action',
        SUCCESS = 'Successfully created action:\n\n%s',
        HINT = 'Add to Reaper action list',
    },
    CLOSE = {
        LABEL = '',
        BUTTON = 'Close',
        HINT = 'Close without creating action',
    }
}

T.EDIT_PRESET_DIALOG = {
    PRESET_NAME = {
        LABEL = 'Preset Name',
        HINT = 'A name for the new preset',
    },
    PRESET_WORD = {
        LABEL = 'Magic Word',
        HINT = 'Typing word + space loads preset',
    },
    SAVE_PRESET = {
        LABEL = '',
        BUTTON_CREATE = 'Save as Preset',
        BUTTON_EDIT = 'Save',
        HINT = 'Save preset',
    },
    DELETE = {
        LABEL = '',
        BUTTON = 'Delete',
        HINT = 'Delete preset',
    },
    CLOSE = {
        LABEL = '',
        BUTTON = 'Close',
        HINT = 'Clse without saving',
    }
}

T.SETTINGS = {
    CREATE_INSIDE_FODLER = {
        LABEL = 'Create sends inside folder',
        HINT = 'New send tracks can be created inside a folder track.',
    },
    SEND_FOLDER_NAME = {
        LABEL = 'Folder name',
        HINT = 'If one does not exist, it will be created when adding sends.',
    },
    SLEEP_MODE = {
        LABEL = 'Use sleep mode',
        HINT = 'If one does not exist, it will be created when adding sends.',
    },
    USE_VIRTUAL_INSTRUMENT_TRACKS = {
        LABEL = 'Use virtual instrument tracks',
        HINT = 'When selecting instruments, create/convert to virtual instrument tracks.',
    },
    PROJECT_SCAN_FOLDER = {
        LABEL = 'Project scanning folder',
        LABEL_BUTTON = 'Add...',
        HINT = 'Where Scout needs to search for projects. Will also scan subfolders.',
        HINT_DELETE = 'Remove this folder',
    },
    RECENTLY_ADDED_DAYS = {
        LABEL = 'Days counted as recent',
        HINT = 'How long should actions and FX be considered recently added.',
    },
    GROUP_ORDER = {
        LABEL = 'Item and FX priority',
        HINT = 'The order in which items are displayed in the search window.',
    },
    FX_TYPE_ORDER = {
        -- LABEL = 'FX type priority',
        HINT = 'The order in which FX are displayed in the search window.',
    },
    SHOW_ONLY_HIGHEST_PRIORITY_FX = {
        LABEL = 'Only show highest priority FX',
        HINT = 'If FX exist in several formats, only show the highest priority ones.'
    },
    CLOSE_AFTER_EXECUTE = {
        LABEL = 'Stay open after action',
        HINT = 'Should Scout stay open after performing an action (adding FX etc...)'
    },
    SHOW_FX_UI = {
        LABEL = 'Open FX UI after adding',
        HINT = 'Open and float FX after adding'
    },
    SHORTCUTS = {
        ENTER_SLEEP_MODE = {
            LABEL = 'Enter sleep mode',
            HINT = 'Sleep mode leads to faster loading times.',
        },
        CLOSE_SCRIPT = {
            LABEL = 'Close script',
            HINT = 'Close script without entering sleep mode.',
        },
        HARD_CLOSE_SCRIPT = {
            LABEL = 'Close script (no sleep)',
            HINT = 'Close script without entering sleep mode.',
        },
        RANDOM_RESULT = {
            LABEL = 'Run random result',
            HINT = 'Randomly select one of the results and run it.',
        },
        MARK_FAVORITE = {
            LABEL = 'Mark favorite',
            HINT = 'Mark search result as favorite.',
        },
    },
    UI_SCALE = {
        LABEL = 'Zoom',
        HINT = 'Interface scale. Double click to enter manually.',
    },
    EXPORT_TAGS = {
        LABEL = '',
        BUTTON_LABEL = 'Export',
        HINT = 'Export user data for use on another system or as a backup.',
    },
    IMPORT_TAGS = {
        LABEL = 'Import / Export',
        BUTTON_LABEL = 'Import (Overwrite)',
        BUTTON_LABEL_MERGE = 'Import (Merge)',
        HINT = 'Import user data. Shift+click to overwrite existing data.',
    },
    CONVERT_FOLDERS_TO_TAGS = {
        LABEL = 'Convert',
        BUTTON_LABEL = 'Folders->Tags',
        HINT = 'Convert FX folders to tags.',
    },
    CONVERT_CATEGORIES_TO_TAGS = {
        LABEL = '',
        BUTTON_LABEL = 'Categories->Tags',
        HINT = 'Convert FX categories to tags.',
    },
    DELETE_ALL_TAGS = {
        LABEL = 'Delete all tags',
        BUTTON_LABEL = 'Delete',
        HINT = 'Delete all tags. This cannot be undone.',
        CONFIRM = 'Are you sure? This cannot be undone.'
    }
}

T.PROGRESS = {
    CONVERT_CATEGORIES = {
        CONVERTING = 'Converting category \'%s\'',
        SUCCESS = 'Conversion successful\n\n%d categories converted\n%d FX tagged',
    },
    CONVERT_FOLDERS = {
        CONVERTING = 'Converting folder \'%s\'',
        SUCCESS = 'Conversion successful.\n\n%d folders converted\n%d FX tagged',
    },
    IMPORT = {
        PARSING = 'Parsing items (%s)...',
        MAPPING_TAGS = 'Mapping tags...',
        MAPPING_ITEMS = 'Mapping items...',
        SUCCESS_MERGE = 'Import successful.\n\n%d items imported (merged)\n%d items could not be imported',
        SUCCESS_OVERWRITE = 'Import successful.\n\n%d items imported (overwritten)\n%d items skipped'
    }
}

T.SETTINGS.LISTS = {
}
T.SEARCH_WINDOW = {
    SEARCH_HINT = {
        [SEARCH_MODE.MAIN] = 'Item search | Press Tab to search filters',
        [SEARCH_MODE.FILTERS] = 'Filter search | Press Tab to search items',
    }
}
T.FILTER_NAMES = {
    [FILTER_TYPES.PRESET] = 'Preset',
    [FILTER_TYPES.TYPE] = 'Result Type',
    [FILTER_TYPES.FX_TYPE] = 'FX Type',
    [FILTER_TYPES.FOLDER] = 'Folder',
    [FILTER_TYPES.CATEGORY] = 'Category',
    [FILTER_TYPES.DEVELOPER] = 'Developer',
    [FILTER_TYPES.TAG] = 'Tag',
    [FILTER_TYPES.OTHER] = 'Other'
}
T.FILTER_NAMES_PLURAL = {
    [FILTER_TYPES.PRESET] = 'Presets',
    [FILTER_TYPES.TYPE] = 'Result Types',
    [FILTER_TYPES.FX_TYPE] = 'FX Types',
    [FILTER_TYPES.FOLDER] = 'Folders',
    [FILTER_TYPES.CATEGORY] = 'Categories',
    [FILTER_TYPES.DEVELOPER] = 'Developers',
    [FILTER_TYPES.TAG] = 'Tags',
    [FILTER_TYPES.OTHER] = 'Others'
}
T.ERROR = {
    NO_DOCK = ([[
No previous dock found.

Please dock manually by dragging
the window to the dock of your choice.

After that, %s will remember
the dock position.]]):format(Scr.name)
}

T.EXPORT_ACTION_TYPE_DESCRIPTIONS = {
    [EXPORT_ACTION_TYPE.APPLY_FILTER] = 'Load current filter',
    [EXPORT_ACTION_TYPE.RUN_RANDOM] = 'Load filter + run random result'
}

for i = 0, #T.EXPORT_ACTION_TYPE_DESCRIPTIONS do
    T.EXPORT_ACTION_TYPE_LIST = (T.EXPORT_ACTION_TYPE_LIST or '') .. T.EXPORT_ACTION_TYPE_DESCRIPTIONS[i] .. '\0'
end

T.SHOW_FX_UI_DESCRIPTIONS = {
    [SHOW_FX_UI.FOLLOW_PREFERENCE] = 'Follow Reaper\'s preferences',
    [SHOW_FX_UI.OPEN] = 'Always open',
    [SHOW_FX_UI.DONT_OPEN] = 'Never open'
}

for i = 0, #T.SHOW_FX_UI_DESCRIPTIONS do
    T.SHOW_FX_UI_LIST = (T.SHOW_FX_UI_LIST or '') .. T.SHOW_FX_UI_DESCRIPTIONS[i] .. '\0'
end


T.IMPORT_SKIP_REASON = {
    [IMPORT_SKIP_REASON.ASSET_NOT_FOUND] = "Filter not found in current system",
    [IMPORT_SKIP_REASON.INCOMPATIBLE_VERSION] = "Incompatible file version",
    [IMPORT_SKIP_REASON.INVALID_FORMAT] = "Invalid filter format"
}

T.SPECIAL_GROUPS = {
    [SPECIAL_GROUPS.FAVORITES] = 'Favorites',
    [SPECIAL_GROUPS.RECENTS] = 'Recents',
    [SPECIAL_GROUPS.PLUGINS] = 'FX'
}

T.RECENTLY_ADDED_EXPLANATION = 
[[The script can only track FX and actions added after it was first 
run. Anything added before that - even if within the selected time 
range - will not appear as recently added.]]

T.SLEEP_MODE_EXPLANATION =
[[TL;DR - The script loads fastest when 'sleep mode' is turned on.
For it to work, the next time the script runs, select 'new instance'.
If you accidentally selected something else, please delete the script
and add it again.

Sleep mode reduces loading times considerably by keeping the script
runningin the background (with minimal resource use) and makes the
experience much faster and smoother. However, since there's currently
no way forscripts to set it on their own, you have to select new
instance manually.]]

T.TURN_ON_SLEEP_MODE = 'Do you wish to turn on sleep mode? (Say yes!)'

T.HINTS = {
    RESET_FILTERS = 'Clear all filters.',
    SAVE_FILTERS = 'Save filter set.',
    RANDOM_ACTION = 'Randomly select one of the results and run it.',
    SAVE_FILTERS_PRESET = 'Save filter set as a preset.',
    SAVE_FILTERS_ACTION = 'Export filter set as a Reaper action.',
    MULTI_TYPE_SELECTION = '%s to execute %d items.',
    -- ACTIVE_FILTER_DEFAULT = '%s: %s',
    ACTIVE_FILTER_REMOVE = 'Remove filter.',
    LOAD_FILTER_DEFAULT = 'Show items whose %s is %s.',
    PRESET_DEFAULT = 'Load preset %s.',
    PRESET_WITH_WORD_DEFAULT = 'Load preset %s. You can also type \'%s\' followed by space to load it.',
    EDIT_PRESET_DEFAULT = 'Edit preset %s.',
    OTHER_FILTERS = {
        ['Untagged'] = 'Show items that have no tags.',
        ['Recently Added'] = 'Show actions and FX that were added recently.'
    },
    TAG_DEFAULT = 'Tag \'%s\'. Double-Click to rename. Right-Click for more options.',
    TAG_CONTEXT_MENU_RENAME = 'Rename tag',
    TAG_CONTEXT_MENU_CREATE_NESTED_TAG = 'Created a new tag within %s',
    TAG_CONTEXT_MENU_DELETE = 'Delete %s and its nested tags. CANNOT BE UNDONE.',
    TAG_POSITIVE = 'Show items that include tag \'%s\'.',
    TAG_NEGATIVE = 'Show items that do not include tag \'%s\'.',
    TAG_REMOVE = 'Remove tag \'%s\' from filter list.',
    DRAG_RESULT_TO_ADD_TAG = 'Add tag \'%s\' to %s. Hold %s to remove tag.',
    DRAG_RESULT_TO_REMOVE_TAG = 'Remove tag \'%s\' from %s.',
    DRAG_RESULT_DEFAULT = 'Drag to tag list to add/remove tags or to a track.',
    DRAG_TAG_DEFAULT = 'Drag to another tag to reorder or to an item to add/remove tag.',
    DRAG_TAG_INTO_TAG = 'Move tag \'%s\' into tag \'%s\'.',
    DRAG_TAG_TO_POSITION_RELATIVE_TO_TAG = 'Move tag \'%s\' %s tag \'%s\'.',
    QUICK_CHAIN_MORE_ACTIONS = 'See all possible actions.',
    QUICK_CHAIN_HOVER = 'Drag FX/Chains here to add them to the quick chain. Alt/Option+Click to remove.',
}

T.MAIN_HELP = [[
Scout - Asset Search & Management for Reaper

Scout is a powerful search and organization tool that helps you quickly find and use all your Reaper assets in one unified interface.

WHAT SCOUT SEARCHES:

- Plugins (VST, VST3, AU, JS) - All your effects and instruments
- Actions - Built-in and custom Reaper actions  
- Projects - Recently opened and scanned project files
- Project Templates - Your saved project templates
- Track Templates - Your saved track templates
- FX Chains - Your custom FX chains
- Tracks - Current project's tracks
- Takes - Current project's active takes in media items
- Markers & Regions

HOW TO USE:

- Type to search across all asset types
- Use the sidebar filters to narrow results by type, folder, category, developer, or tags
- Double click any result to execute/load it instantly
- Use shift/ctrl/cmd to select multiple results
- Drag results to tracks to add them directly
- Right-click results to see possible actions, as well as keyboard shortcuts for quick access

FILTER SEARCH MODE:
- Press Tab to switch between searching items and searching filters
- When in filter search mode, type to search for filters, tags and presets by name
- Pressing Enter on a filter will apply it to the current search and return to item search mode
- Pressing Shift+Enter on a filter will apply it and stay in filter search mode

ADVANCED FEATURES:

TAGGING SYSTEM:
- Drag items to tags in the sidebar to organize your assets (Alt-dragging removes tags)
- Create nested tags for hierarchical organization
- Right-click tags for rename/delete options
- Tags can be either used either positively (to include) or negatively (to exclude) in filters
- Tags can be combined with other tags and filters for powerful searches

PRESETS: 
- Save complex filter combinations as presets for quick access
- Presets can be assigned magic words for quick loading
- Type the magic word followed by space to load the preset instantly
- Type the magic word followed by a question mark to randomly execute one of the preset's results

FAVORITES
- Mark frequently used items (Ctrl+F by default)

RANDOM EXECUTION:
- Randomly select and execute one of the current search results (Default: Shift+Ctrl/Cmd+R)

CUSTOM ACTIONS:
- Create custom Reaper actions that instantly load presets or run random results

SLEEP MODE:
- Enable sleep mode for faster loading times (recommended)

KEYBOARD SHORTCUTS:
- Enter: Execute selected item(s)
- Escape: Clear search or close (depending on sleep mode setting)
- Ctrl+A: Select all results
- Ctrl+F: Toggle favorite status of selected items
- Ctrl+R: Execute random result from current search

TIPS:
- Enable Sleep Mode for fastest performance
- Use the sidebar to organize assets with tags and filters  
- Drag items directly to tracks to add them
- Create presets for commonly used filter combinations
- Import/export your tags and favorites to share between systems

Scout makes your Reaper workflow faster by putting everything you need at your fingertips with instant search and smart organization.
]]
