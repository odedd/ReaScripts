-- @noindex
T = {}

T.IMPORTED_TAGS_GROUP = 'Imported'
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
T.EXPORT_QUICKACTION_AS_ACTION_DIALOG = {
    INFO = 'Create a Reaper action that will run one of the quickchain\'s actions.'
    ,
    ACTION_TYPE = {
        LABEL = 'Action Type',
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

T.EDIT_QUICKCHAIN_PRESET_DIALOG = {
    PRESET_NAME = {
        LABEL = 'Name',
        HINT = 'A name for the new QuickChain preset',
    },
    PRESET_WORD = {
        LABEL = 'Magic Word',
        HINT = 'Typing word + space loads/runs QuickChain preset',
    },
    UPDATE_PRESET_WITH_CURRENT_CHAIN = {
        LABEL = 'Update with loaded chain',
        HINT = 'Update QuickChain preset with loaded chain',
    },
}

T.EDIT_PRESET_DIALOG = {
    PRESET_NAME = {
        LABEL = 'Name',
        HINT = 'A name for the new preset',
    },
    PRESET_WORD = {
        LABEL = 'Magic Word',
        HINT = 'Typing word + space loads preset',
    },
    UPDATE_PRESET_WITH_CURRENT_FILTERS = {
        LABEL = 'Update filters',
        HINT = 'Update preset with current filters',
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

T.SEARCH_WINDOW = {
    SEARCH_HINT = {
        [SEARCH_MODE.MAIN] = 'Item search | Press Tab to search filters',
        [SEARCH_MODE.SEND_BUDDY] = 'Send Buddy search | Press Tab to search filters',
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

T.AFTER_ACTION_DESCRIPTIONS = {
    [AFTER_ACTION.DO_NOTHING] = 'Do Nothing',
    [AFTER_ACTION.CLOSE] = 'Close Script/Enter Sleep Mode',
    [AFTER_ACTION.CLEAR_TEXT] = 'Clear text search'
}

for i = 0, #T.AFTER_ACTION_DESCRIPTIONS do
    T.AFTER_ACTION_LIST = (T.AFTER_ACTION_LIST or '') .. T.AFTER_ACTION_DESCRIPTIONS[i] .. '\0'
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


T.SETTINGS = {
    LISTS = {},

    CREATE_INSIDE_FODLER = {
        LABEL = 'Create sends in folder',
        HINT = 'New send tracks can be created inside a folder track.',
    },
    RESET_FILTERS_ON_WAKEUP = {
        LABEL = 'Reset filters on wakeup',
        HINT = 'Reset filters and clear QuickChain when waking up from sleep mode.',
    },
    LOAD_DEFAULT_PRESET = {
        LABEL = 'Use default preset',
        HINT = 'Open Scout with a default preset on launch, and on wakeup (if resetting filters).',
    },
    DEFAULT_PRESET = {
        LABEL = 'Default preset',
        HINT = 'Select preset to open when Scout launches or wakes up (if resetting filters).',
    },
    OVERRIDE_DEFAULT_SEND_VOLUME = {
        LABEL = 'Override send volume',
        HINT = 'Override the default send volume for new sends.',
    },
    SEND_VOLUME = {
        LABEL = 'Send volume',
        HINT = 'The volume for new sends. Set to -inf to disable.',
    },
    SEND_FOLDER_NAME = {
        LABEL = 'Folder name',
        HINT = 'If one does not exist, it will be created when adding sends.',
    },
    SLEEP_MODE = {
        LABEL = 'Use sleep mode',
        HINT = 'If one does not exist, it will be created when adding sends.',
    },
    CENTER_ON_OPEN = {
        LABEL = 'Center on open',
        HINT = 'Center the main window on the screen when opened.',
    },
    USE_VIRTUAL_INSTRUMENT_TRACKS = {
        LABEL = 'Use instrument tracks',
        HINT = 'When selecting instruments, create/convert to virtual instrument tracks.',
    },
    PROJECT_SCAN_FOLDER = {
        LABEL = 'Project scanning folder',
        LABEL_BUTTON = 'Add...',
        HINT = 'Where Scout needs to search for projects. Will also scan subfolders.',
        HINT_DELETE = 'Remove this folder',
    },
    SCAN_RECENT_PROJECTS = {
        LABEL = 'Scan recent projects',
        HINT = 'Scan Reaper\'s recently open projects and add them to the list.',
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
        HINT = 'The order in which FX are displayed in the search window, based on their type.',
    },
    VARIANT_ORDER = {
        -- LABEL = 'FX type priority',
        HINT = 'The order in which FX are displayed in the search window, based on their variant.',
    },
    SHOW_ONLY_HIGHEST_PRIORITY_FX = {
        LABEL = 'Highest priority FX type only',
        HINT = 'If FX exist in several formats, only show the highest priority one.'
    },
    SHOW_ONLY_HIGHEST_VARIANT_FX = {
        LABEL = 'Highest priority variant only',
        HINT = 'If FX exist in several variants, only show the highest priority one.'
    },
    SHOW_FX_UI = {
        LABEL = 'Open FX UI after adding',
        HINT = 'Open and float FX after adding'
    },
    AFTER_ACTION = {
        LABEL = 'Post-perform bahavior',
        HINT = 'What to do after action is performed',
        TOP_BAR_HINT = 'After action is performed: %s'
    },
    SHOW_INVISIBLE_TAKE_MARKERS = {
        LABEL = 'Invisible take markers',
        HINT = 'Show take markers that are outside the item boundaries.',
    },
    SHOW_INVISIBLE_TRACKS = {
        LABEL = 'Invisible tracks',
        HINT = 'Show tracks that are not visible in the TCP.',
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
        TOGGLE_AFTER_ACTION = {
            LABEL = 'Toggle post-perform behavior',
            HINT = ('Toggle between %s, %s and %s.'):format(T.AFTER_ACTION_DESCRIPTIONS[AFTER_ACTION.CLOSE],T.AFTER_ACTION_DESCRIPTIONS[AFTER_ACTION.CLEAR_TEXT], T.AFTER_ACTION_DESCRIPTIONS[AFTER_ACTION.DO_NOTHING]),
        },
        PERFORM_ACTION = {
            LABEL = 'Perform selected item',
            HINT = 'Perform selected item or QuickChain.',
        },
        TOGGLE_SEARCH_MODE = {
            LABEL = 'Toggle search mode',
            HINT = 'Toggle between item and filter search mode.',
        },
        HARD_CLOSE_SCRIPT = {
            LABEL = 'Close script (no sleep)',
            HINT = 'Close script without entering sleep mode.',
        },
        RANDOM_RESULT = {
            LABEL = 'Run random result',
            HINT = 'Randomly select one of the results and run it.',
        },
        CLEAR_FILTERS = {
            LABEL = 'Clear filters',
            HINT = 'Clear all filters and tags from the search window.',
        },
        ADD_TO_QUICK_CHAIN = {
            LABEL = 'Add to QuickChain',
            HINT = 'Add selected FX/FX Chains to the QuickChain.',
        },
        COPY_TAGS = {
            LABEL = 'Copy Item\'s Tags',
            HINT = 'Copy selected item\'s tags to the clipboard.',
        },
        PASTE_TAGS = {
            LABEL = 'Paste Item\'s Tags',
            HINT = 'Paste copied tags to selected item(s).',
        },
        QUICK_TAG = {
            LABEL = 'Quick Tag',
            HINT = 'Open Quick Tag window.',
        },
        CLEAR_QUICK_CHAIN = {
            LABEL = 'Clear QuickChain',
            HINT = 'Clear the QuickChain.',
        },
        MARK_FAVORITE = {
            LABEL = 'Mark favorite',
            HINT = 'Mark search result as favorite.',
        },
        MARK_HIDDEN = {
            LABEL = 'Hide item',
            HINT = 'Mark item as hidden.',
        },
        TOGGLE_SIDEBAR = {
            LABEL = 'Toggle side bar',
            HINT = 'Show/hide the side bar.',
        },
        TOGGLE_QUICK_CHAIN = {
            LABEL = 'Toggle QuickChain',
            HINT = 'Show/hide the QuickChain.',
        },
        SHOW_SETTINGS = {
            LABEL = 'Show settings',
            HINT = 'Open the settings window.',
        },
        SELECT_ALL_RESULTS = {
            LABEL = 'Select all results',
            HINT = 'Select all search results.',
        },
        SHOW_HELP = {
            LABEL = 'Show help',
            HINT = 'Open the help window.',
        },
        TOGGLE_DOCK = {
            LABEL = 'Dock/Undock script',
            HINT = 'Dock/undock the script in the Reaper docker.',
        },
        TOGGLE_MINIMAL_MODE = {
            LABEL = 'Toggle minimal mode',
            HINT = 'Toggle minimal mode on and off.',
        }
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
    TAG_DEFAULT_COLOR = {
        LABEL = 'Default tag color',
        HINT = 'Default color for all tags.',
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
        SUCCESS_MERGE =
        'Import successful (merged).\n\n%d tags imported, %d existing tags preserved\n%d items were tagged, %d were skipped\n%d presets imported, %d skipped\n%d QuickChain presets imported, %d skipped\n%d hidden items imported, %d skipped\n%d favorites imported, %d skipped',
        SUCCESS_OVERWRITE =
        'Import successful (overwritten).\n\n%d tags imported, %d existing tags replaced\n%d items were tagged, %d were skipped\n%d presets imported, %d skipped\n%d QuickChain presets imported, %d skipped\n%d hidden items imported, %d skipped\n%d favorites imported, %d skipped'
    }
}

T.RECENTLY_ADDED_EXPLANATION =
[[The script can only track FX and actions added after it was first
run. Anything added before that - even if within the selected time
range - will not appear as recently added.]]

T.SLEEP_MODE_EXPLANATION =
[[TL;DR - The script loads fastest when 'sleep mode' is turned on.
For it to work, the next time the script runs, select 'new instance',
and check 'Remember my answer for this script'.
If you accidentally selected something else, please delete the script
and add it again.

Sleep mode reduces loading times considerably by keeping the script
runningin the background (with minimal resource use) and makes the
experience much faster and smoother. However, since there's currently
no way for scripts to set it on their own, you have to select new
instance manually.]]

T.TURN_ON_SLEEP_MODE = 'Do you wish to turn on sleep mode? (Say yes!)'


T.HINTS = {
    RESET_FILTERS = 'Clear all filters.',
    SAVE_FILTERS = 'Save filter set.',
    RANDOM_ACTION = 'Randomly select one of the results and run it.',
    SAVE_FILTERS_PRESET = 'Save filter set as a preset.',
    SAVE_FILTERS_ACTION = 'Export filter set as a Reaper action.',
    SAVE_QUICKCHAIN_MENU = 'Save/Edit/Delete QuickChain presets, and create a Reaper action from QuickChain.',
    QUICKCHAIN_PRESETS_MENU = 'Load QuickChain presets.',
    QUICKCHAIN_PRESETS_MENU_LOAD_PRESET = 'Load QuickChain preset \'%s\' into current QuickChain.',
    SAVE_QUICKCHAIN_PRESET = 'Save QuickChain preset.',
    DELETE_QUICKCHAIN_PRESET = 'Delete QuickChain preset.',
    EDIT_QUICKCHAIN_PRESET = 'Edit currently loaded QuickChain preset.',
    SAVE_QUICKCHAIN_ACTION = 'Export QuickChain as a Reaper action.',
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
    TAG_DEFAULT_SHIFT = 'Shift+Drag to another tag to merge with it.',
    TAG_CONTEXT_MENU_RENAME = 'Rename tag',
    TAG_CONTEXT_MENU_COLOR = 'Set tag\'s color',
    TAG_CONTEXT_MENU_CREATE_NESTED_TAG = 'Created a new tag within %s',
    TAG_CONTEXT_MENU_COLLAPSE_DESCENDANTS = 'Collapse %s and its nested tags',
    TAG_CONTEXT_MENU_DELETE = 'Delete %s and its nested tags. CANNOT BE UNDONE.',
    HOVER_TAG_ALT_TO_DELETE = '%s+click to remove tag.',
    RESULT_CONTEXT_MENU_COPY_TAGS_TO_ALL_TYPES = 'Copy selected item\'s tags to all the FX\'s other formats and variants',
    RESULT_CONTEXT_MENU_CLEAR_TAGS = 'Remove selected item\'s tags.',
    RESULT_CONTEXT_MENU_COPY_TAGS = 'Copy selected item\'s tags to the clipboard.',
    RESULT_CONTEXT_MENU_PASTE_TAGS = 'Paste tags from the clipboard.',
    RESULT_CONTEXT_MENU_ADD_TAGS = 'And new tags to selected item(s).',
    RESULT_CONTEXT_MENU_ACTIVE_TAGS = 'See all active tags for selected item(s).',
    TAG_POSITIVE = 'Include: Show items that include tag \'%s\'.',
    TAG_NEGATIVE = 'Exclude: Show items that do not include tag \'%s\'.',
    TAG_HIDE = 'Show/hide tag \'%s\' in the results table.',
    TAG_REMOVE = 'Remove tag \'%s\' from filter list.',
    DRAG_RESULT_TO_ADD_TAG = 'Add tag \'%s\' to %s. Hold %s to remove tag.',
    DRAG_RESULT_TO_REMOVE_TAG = 'Remove tag \'%s\' from %s.',
    DRAG_RESULT_DEFAULT = 'Drag to tag list to add/remove tags or to a track.',
    DRAG_TAG_DEFAULT = 'Drag to another tag to reorder or to an item to add/remove tag. Hold Shift to merge tags.',
    DRAG_TAG_INTO_TAG = 'Move tag \'%s\' into tag \'%s\'. Hold Shift to merge with tag.',
    DRAG_TAG_INTO_TAG_MERGE = 'Merge tag \'%s\' with tag \'%s\'.',
    DRAG_TAG_INTO_TAG_COPY = 'Copy assets tagged with \'%s\' to tag \'%s\'.',
    DRAG_TAG_TO_POSITION_RELATIVE_TO_TAG = 'Move tag \'%s\' %s tag \'%s\'.',
    QUICK_CHAIN_MORE_ACTIONS = 'See all possible actions.',
    QUICK_CHAIN_HOVER = 'Drag FX/Chains here to add them to the QuickChain. Alt/Option+Click to remove.',
}


T.KEYBOARD_MODIFIERS_HELP = [[
#`KEYBOARD MODIFIERS`#
Keyboard modifiers can be used to perform various actions on the search results. The modifiers change based on the type of result.

`Right-Clicking` a result will show you the available actions and their keyboard shortcuts.
]]

T.HELP_ACKNOWLEDGEMENTS = [[
While $script is a result of countless hours of work, it could not have been done without the prior work of many incredible and talented programmers and contributors to the Reaper scripting community.

I'd like to personally thank those who knowingly or unknowingly contributed:
- #`cfillion`# for creating `ReaImGui`, `ReaPack` and so much more
- #`nvk`# for creating `nvk_SEARCH` which was a huge inspiration for $script
- #`Neutronic`# for `Quick Adder` which, for me, started this whole thing
- #`X-Raym`# for the ReaScript documentation - an invalueable resource
]]

T.MAIN_HELP = [[
#`WHAT IS $SCRIPT?`#
$script is a powerful search and organization tool that helps you quickly find and use all your Reaper assets in one unified interface, prioritizing speed and efficiency, allowing you to search for and manage your assets without leaving the keyboard.

$script searches for #FX#, #Actions#, #Projects#, #Project Templates#, #Track Templates#, #FX Chains#, #Tracks#, #Takes#, #Markers#, #Regions#, #Take Markers# and #QuickChain Presets#.

#`USAGE`#
- Type to search across all asset types
- Use the sidebar filters to narrow results
- `Double-Click` any result to execute/load it instantly
- Use myriad keyboard modifiers for more actions (see tab)
- `Right-click` results for available actions and keyboard shortcuts
- Use `Shift/$ctrl` to select multiple results
- `Drag` results to tracks to add them directly
- `Drag` results to an empty area to create a new track
- Determine fx type and variant `order` and `priority`
- Only see the `highest priority` fx type and variant
- Create #QuickChains# to `batch process` FX and chains
- Randomly execute a results with $shortcut:runRandomResult
- Use $script in `minimal mode` for a more compact interface

#`TAGGING SYSTEM`#
- Assign tags to items for easy organization
- Filter using tags, either `inclusively` or `exclusively`
- Inclusive tags show items that `have` the tag
- Exclusive tags show items that `do not` have the tag
- Tags can be `combined` with other tags/filters
- Create `nested tags` for hierarchical organization
- Applied tags include their children in the results
- Set `custom colors` to tags. Nested tags inherit parents' colors
- `Hide` tags and their children from the results area
- Hover over a tag in the results area to see its parents
- `Drag` items to tags to add/remove (`$alt-Click` to remove)
- `Double-Click` tags to rename them
- `Right-Click` tags for more options (delete, create nested tag)
- `Right-Click` search results to copy, paste and clear tags
- `Auto-add` tag to the selected FX's various `formats` and `variants`

#`FILTER SEARCH MODE`#
- Press `Tab` to switch between item search and filter search
- In filter search mode, type to search filters, tags and presets
- `Enter` applies filter and returns to item search
- `Shift+Enter` applies filter without returning to item search

#`QUICKCHAIN`#
- Click icon or press $shortcut:toggleQuickChain to show/hide the QuickChain sidebar
- Build chains by combining FX/FX Chains from search results
- Control order and add items from different searches
- `Drag/Drop` or press $shortcut:addToQuickChain to add FX/Chains to the QuickChain
- `$alt/+Click` to removes items from the QuickChain
- $shortcut:clearQuickChain to clear the QuickChain
- Execute chain by pressing `Enter` or by clicking the Lightning button
- Click the `...` menu for more actions and keyboard shortcuts

#`PRESETS`#
- Save filter combinations as `filter presets`
- Save QuickChains as `QuickChain presets` for quick recall
- Set a #default preset# to load when $script starts or wakes up

#`MAGIC WORDS`#
- Assign `Magic Words` to filter/QuickChain presets for instant loading
- `Result type filters` (FX, Markers etc...) have magic words built-in
- Type `Magic Word + space` to load preset/QuickChain/result type
- Type `Magic Word + ?` to randomly execute one of the preset's results

#`QUICK TAG WINDOW`#
- Press $shortcut:quickTag to `quickly tag items`
- Create `new tags` at root or nested under others
- Press `Enter` to tag or `$alt+Click` to remove tags
- Press `Shift+Enter` to keep adding/removing tags

#`FAVORITES, RECENTS, HIDDEN AND RECENTLY ADDED ITEMS`#
- Press $shortcut:markFavorite to mark frequently used items
- Press $shortcut:markHidden to `hide`/`unhide` unneeded items
- Recently used items are automatically shown at the top of the list
- Use filter `Other->Hidden` to see hidden items
- Use filter `Other->Recently Added` to see Recently added FX/Actions
- Scout can only track items added after it was first run

#`CUSTOM ACTIONS`#
- Filters and QuickChain presets can be exported as `custom Reaper actions`
- Filter actions can either `load a filter` or `randomly run a result`
- QuickChains actions can instantly perform each of $script's actions 

#`EXPORT/IMPORT`#
- Export your data to share between systems
- Data includes `tags`, `presets`, `favorites`, `hidden items` and `QuickChains`
- Importing can either `overwrite` or `merge` with existing data
- When imported, $script will try its best to match existing items
- If an item is not found on the receiving system, it will be ignored

#`TIPS`#
- Enable `Sleep Mode` for fastest loading
- Start quickly by `converting FX folders and categories` to tags
- Create `filter presets` for commonly used filter combinations
- Use `Magic Words` and `Reaper actions` to quickly load filter presets
- Boost your creativity by letting $script run `random results`
- Use `filter search mode` to quickly filter using the keyboard
- Use `Quick Tag` window to quickly tag items using the keyboard
- Use `QuickChain` to batch process FX and chains efficiently
- Use `Magic Words` and `Reaper actions` to quickly run QuickChain presets
- Use the settings to `customize` $script to your workflow]]
