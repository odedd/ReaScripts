-- @noindex

-- ! CONSTANTS

-- * --------------------
-- * opertaion ----------
-- * --------------------

STATUS = {
    IGNORE = 0,
    SCANNED = 1,
    MINIMIZING = 9,
    MINIMIZED = 10,
    NOTHING_TO_MINIMIZE = 11,
    MOVING = 50,
    COPYING = 51,
    DELETING = 52,
    MOVING_TO_TRASH = 53,
    COLLECTING = 69,
    COLLECTED = 70,
    DONE = 100,
    ERROR = 1000
}

STATUS_DESCRIPTIONS = {
    [STATUS.IGNORE] = 'Not Minimizing',
    [STATUS.SCANNED] = 'Scanned',
    [STATUS.MINIMIZING] = 'Minimizing',
    [STATUS.MINIMIZED] = 'Minimized',
    [STATUS.NOTHING_TO_MINIMIZE] = 'Nothing to minimize',
    [STATUS.MOVING] = 'Moving',
    [STATUS.COPYING] = 'Copying',
    [STATUS.DELETING] = 'Deleting Original',
    [STATUS.MOVING_TO_TRASH] = 'Moving Orig. To Trash',
    [STATUS.COLLECTING] = 'Collecting',
    [STATUS.COLLECTED] = 'Collected',
    [STATUS.DONE] = 'Done',
    [STATUS.ERROR] = 'Error'
}

ALL_FORMATS = {
    VORBIS = { type = 'COMPRESSED', extension = 'ogg' },
    OGG = { type = 'COMPRESSED', extension = 'ogg' },
    OPUS = { type = 'COMPRESSED', extension = 'opus' },
    MOGG = { type = 'COMPRESSED', extension = 'mogg' },
    MP3 = { type = 'COMPRESSED', extension = 'mp3' },
    FLAC = { type = 'LOSSLESS', extension = 'flac' },
    WAVPACK = { type = 'LOSSLESS', extension = 'wv' },
    AIFF = { type = 'UNCOMPRESSED', extension = 'aiff' },
    WAVE = { type = 'UNCOMPRESSED', extension = 'wav' },
    BW64 = { type = 'UNCOMPRESSED', extension = 'bw64' },
    BWF = { type = 'UNCOMPRESSED', extension = 'bwf' },
    RF64 = { type = 'UNCOMPRESSED', extension = 'rf64' },
    SD2 = { type = 'UNCOMPRESSED', extension = 'sd2' },
    WAV = { type = 'UNCOMPRESSED', extension = 'wav' },
    W64 = { type = 'UNCOMPRESSED', extension = 'w64' },
    WMV = { type = 'INCOMPATIBLE', extension = 'wmv' },
    AVI = { type = 'INCOMPATIBLE', extension = 'avi' },
    MOV = { type = 'INCOMPATIBLE', extension = 'mov' },
    EDL = { type = 'INCOMPATIBLE', extension = 'edl' },
    MIDI = { type = 'INCOMPATIBLE', extension = 'midi' },
    RPP_PROJECT = { type = 'SUBPROJECT', extension = 'rpp' },
    MUSICXML = { type = 'INCOMPATIBLE', extension = 'musicxml' },
    MPEG = { type = 'INCOMPATIBLE', extension = 'mpeg' },
    KAR = { type = 'INCOMPATIBLE', extension = 'kar' },
    QT = { type = 'INCOMPATIBLE', extension = 'qt' },
    SYX = { type = 'INCOMPATIBLE', extension = 'syx' },
    REX2 = { type = 'SPECIAL', extension = 'rex2' },
    CAF = { type = 'TO_TEST', extension = 'caf' },
    ACID = { type = 'TO_TEST', extension = 'acid' },
    CDDA = { type = 'TO_TEST', extension = 'cdda' },
    ['RAW/PCM'] = { type = 'TO_TEST', extension = 'raw' },
    RADAR = { type = 'TO_TEST', extension = 'radar' }
}

local function createTablesFromFormats(allFormats)
    local mediaExtensions = {}
    local mediaTypes = {} -- Initialize an empty table for mediaTypes

    for format, data in pairs(allFormats) do
        local extension = data.extension
        local formatType = data.type

        -- Add to mediaExtensions table
        table.insert(mediaExtensions, extension)

        -- Add to mediaTypes table dynamically
        if not mediaTypes[formatType] then
            mediaTypes[formatType] = {} -- Create a new empty table for the format type
        end

        table.insert(mediaTypes[formatType], format)
    end

    -- Add 'VIDEO' key to mediaTypes table
    mediaTypes['VIDEO'] = { 'VIDEO' }

    return mediaExtensions, mediaTypes
end

MEDIA_EXTENSIONS, MEDIA_TYPES = createTablesFromFormats(ALL_FORMATS)

FILE_TYPES = {
    AUDIO = 0,
    VIDEO = 1,
    RS5K = 2,
    SUBPROJECT = 3
}

FILE_TYPE_DESCRPTIONS = {
    [FILE_TYPES.AUDIO] = 'Audio',
    [FILE_TYPES.VIDEO] = 'Video',
    [FILE_TYPES.RS5K] = 'RS5K',
    [FILE_TYPES.SUBPROJECT] = 'RPP',
}
-- * --------------------
-- * settings -----------
-- * --------------------

-- bitwise
COLLECT = {
    EXTERNAL = 1,
    VIDEO = 2,
    RS5K = 4
}

COLLECT_OPERATION = {
    COPY = 0,
    MOVE = 1
}
COLLECT_BACKUP_OPERATION = {
    COPY = 0,
    MOVE = 1
}

COLLECT_OPERATION_DESCRIPTIONS = {
    [COLLECT_OPERATION.COPY] = 'Copy from original location',
    [COLLECT_OPERATION.MOVE] = 'Move from original location'
}


for i = 0, #COLLECT_OPERATION_DESCRIPTIONS do
    COLLECT_OPERATIONS_LIST = (COLLECT_OPERATIONS_LIST or '') .. COLLECT_OPERATION_DESCRIPTIONS[i] .. '\0'
end

DELETE_METHOD = {
    MOVE_TO_TRASH = 0,
    DELETE_FROM_DISK = 1,
    KEEP_IN_FOLDER = 2
}

DELETE_METHOD_DESCRIPTIONS = {
    [DELETE_METHOD.MOVE_TO_TRASH] = 'Move to trash',
    [DELETE_METHOD.DELETE_FROM_DISK] = 'Delete immediately',
    [DELETE_METHOD.KEEP_IN_FOLDER] = 'Do not delete'
}

for i = 0, #DELETE_METHOD_DESCRIPTIONS do
    DELETE_METHODS_LIST = (DELETE_METHODS_LIST or '') .. DELETE_METHOD_DESCRIPTIONS[i] .. '\0'
end

MINIMIZE_SOURCE_TYPES = {
    UNCOMPRESSED_AND_LOSSLESS = 0,
    ALL = 1
}
MINIMIZE_SOURCE_TYPES_DESCRIPTIONS = {
    [MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS] = 'Uncompressed & Lossless',
    [MINIMIZE_SOURCE_TYPES.ALL] = 'Any audio file'
}
for i = 0, #MINIMIZE_SOURCE_TYPES_DESCRIPTIONS do
    MINIMIZE_SOURCE_TYPES_LIST = (MINIMIZE_SOURCE_TYPES_LIST or '') .. MINIMIZE_SOURCE_TYPES_DESCRIPTIONS[i] .. '\0'
end

GLUE_FORMATS = {
    WAV24 = 0,
    WAV32F = 1,
    FLAC24 = 2,
    WAVPACK24 = 3,
    WAVPACK32F = 4
}

GLUE_FORMATS_DETAILS = {
    [GLUE_FORMATS.WAV24] = {
        description = 'WAV 24bit',
        formatString = 'ZXZhdxgAAA==',
        type = MEDIA_TYPES.UNCOMPRESSED
    },
    [GLUE_FORMATS.WAV32F] = {
        description = 'WAV 32bit fp',
        formatString = 'ZXZhdyAAAA==',
        type = MEDIA_TYPES.UNCOMPRESSED
    },
    [GLUE_FORMATS.FLAC24] = {
        description = 'FLAC 24bit',
        formatString = 'Y2FsZhgAAAAIAAAA',
        type = MEDIA_TYPES.LOSSLESS
    },
    [GLUE_FORMATS.WAVPACK24] = {
        description = 'WAVPACK 24bit',
        formatString = 'a3B2dwAAAAABAAAAAAAAAAEAAAA=',
        type = MEDIA_TYPES.LOSSLESS
    },
    [GLUE_FORMATS.WAVPACK32F] = {
        description = 'WAVPACK 32bit fp',
        formatString = 'a3B2dwAAAAADAAAAAAAAAAEAAAA=',
        type = MEDIA_TYPES.LOSSLESS
    }
}
for i = 0, #GLUE_FORMATS_DETAILS do
    GLUE_FORMATS_LIST = (GLUE_FORMATS_LIST or '') .. GLUE_FORMATS_DETAILS[i].description .. '\0'
end

FREEZE_HANDLING = {
    KEEP = 0,
    REMOVE = 1,
}

FREEZE_HANDLING_DESCRIPTIONS = {
    [FREEZE_HANDLING.KEEP] = 'Keep freeze source files, unminimized',
    [FREEZE_HANDLING.REMOVE] = 'Make frozen tracks permanent & remove association to source files'
}

for i = 0, #FREEZE_HANDLING_DESCRIPTIONS do
    FREEZE_HANDLING_LIST = (FREEZE_HANDLING_LIST or '') .. FREEZE_HANDLING_DESCRIPTIONS[i] .. '\0'
end