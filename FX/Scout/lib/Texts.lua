-- @noindex
T = {}

T.EXPORT_ACTION_DIALOG = {
    NAME = {--TODO: Update this
        LABEL = 'Action Name',
        HINT = 'A name for the new action',
    },
        EXPORT = {
        LABEL = '',
        BUTTON = 'Export as Action',
        SUCCESS = 'Successfully created action:\n%s',
        HINT = 'temp',
    },
    CLOSE = {
        LABEL = '',
        BUTTON = 'Close',
        HINT = 'temp',
    }
}

T.EDIT_FILTER_DIALOG = {
    PRESET_NAME = {--TODO: Update this
        LABEL = 'Preset Name',
        HINT = 'A name for the new preset',
    },
    PRESET_WORD = {--TODO: Update this
        LABEL = 'Magic Word',
        HINT = 'A name for the new magic word',
    },
    SAVE_PRESET = {
        LABEL = '',
        BUTTON_CREATE = 'Save as Preset',
        BUTTON_EDIT = 'Save',
        HINT = 'temp',
    },
    DELETE = {
        LABEL = '',
        BUTTON = 'Delete',
        HINT = 'temp',
    },
    CLOSE = {
        LABEL = '',
        BUTTON = 'Close',
        HINT = 'temp',
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
    PROJECT_SCAN_FOLDER = {
        LABEL = 'Project scanning folder',
        LABEL_BUTTON = 'Add...',
        HINT = 'Where Scout needs to search for projects. Will also scan subfolders.',
        HINT_DELETE = 'Remove this folder',
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
        LABEL = 'Import / Export',
        BUTTON_LABEL = 'Export',
        HINT = 'Export user data for use on another system or as a backup.',
    },
    IMPORT_TAGS = {
        LABEL = '',
        BUTTON_LABEL = 'Import (Overwrite)',
        BUTTON_LABEL_MERGE = 'Import (Merge)',
        HINT = 'Import user data. Shift+click to overwrite existing data.',
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
    FILTER_DEFAULT = 'Show items whose %s is %s.',
    PRESET_DEFAULT = 'Load preset %s.',
    EDIT_PRESET_DEFAULT = 'Edit preset %s.',
    OTHER_FILTERS = {
        ['Untagged'] = 'Show items that have no tags.'
    },
    TAG_DEFAULT = 'Tag \'%s\'. Double-Click to rename.',
    TAG_POSITIVE = 'Show items that include tag \'%s\'.',
    TAG_NEGATIVE = 'Show items that do not include tag \'%s\'.',
    TAG_REMOVE = 'Remove tag \'%s\' from filter list.',
    DRAG_RESULT_TO_ADD_TAG = 'Add tag \'%s\' to %s. Hold %s to remove tag.',
    DRAG_RESULT_TO_REMOVE_TAG = 'Remove tag \'%s\' from %s.',
    DRAG_RESULT_DEFAULT = 'Drag to tag list to add/remove tags or to a track.',
    DRAG_TAG_DEFAULT = 'Drag to another tag to reorder or to an item to add/remove tag.',
    DRAG_TAG_INTO_TAG = 'Move tag \'%s\' into tag \'%s\'.',
    DRAG_TAG_TO_POSITION_RELATIVE_TO_TAG = 'Move tag \'%s\' %s tag \'%s\'.',
}