-- @noindex
STATUS = {
    IGNORE = 0,
    SCANNED = 1,
    MINIMIZING = 9,
    MINIMIZED = 10,
    MOVING = 50,
    COPYING = 51,
    DELETING = 52,
    MOVING_TO_TRASH = 53,
    DONE = 100,
    ERROR = 1000
}

STATUS_DESCRIPTIONS = {
    [STATUS.IGNORE] = 'Ignore',
    [STATUS.SCANNED] = 'Scanned',
    [STATUS.MINIMIZING] = 'Minimizing',
    [STATUS.MINIMIZED] = 'Minimized',
    [STATUS.MOVING] = 'Moving',
    [STATUS.COPYING] = 'Copying',
    [STATUS.DELETING] = 'Deleting',
    [STATUS.MOVING_TO_TRASH] = 'Moving To Trash',
    [STATUS.DONE] = 'Done',
    [STATUS.ERROR] = 'Error'
}

FORMATS = {
    COMPRESSED = {'VORBIS', 'OGG', 'OPUS', 'MOGG', 'MP3'},
    LOSSLESS = {'FLAC', 'WAVPACK'},
    UNCOMPRESSED = {'AIFF', 'WAVE', 'BW64', 'BWF', 'RF64', 'SD2', 'WAV', 'W64'},
    INCOMPATIBLE = {'WMV', 'AVI', 'MOV', 'EDL', 'MIDI', 'MUSICXML', 'MPEG', 'KAR', 'QT', 'SYX'},
    SPECIAL = {'REX2'},
    TO_TEST = {'CAF', 'ACID', 'CDDA', 'RAW/PCM', 'RADAR'},
    VIDEO = {'VIDEO'}
}

local function reverseItem(item)
    r.SelectAllMediaItems(0, false)
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(41051, 0)
end

-- Collect media files and occurrences
function collectMediaFiles()

    local function getTakeSourcePositions(take, srclen)
        -- copy item to new track
        local item = r.GetMediaItemTake_Item(take)
        -- reset item timebase to time, because it screws up taking, but save current setting to re-apply them after copying
        local tmpItemAutoStretch = r.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH")
        local tmpBeatAttachMode = r.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE")
        r.SetMediaItemInfo_Value(item, "C_AUTOSTRETCH", 0)
        r.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0) -- ]]
        local savedTake = r.GetActiveTake(item)
        r.SetActiveTake(take)

        -- restore
        local track = r.GetMediaItem_Track(item)

        -- calculate source positions with regards to stretch markers, by creating "faux" take markers at take's start and end
        local itemLength = r.GetMediaItemInfo_Value(item, "D_LENGTH")

        local takePlayrate = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
        local takeSource = r.GetMediaItemTake_Source(take)
        local sourceParent = r.GetMediaSourceParent(takeSource)
        if sourceParent then
            takeSource = sourceParent
        end
        local srclen = srclen or r.GetMediaSourceLength(takeSource)

        local numStrtchMarkers = r.GetTakeNumStretchMarkers(take)

        local endPos = OD_Round(itemLength * takePlayrate, 9)
        local startPos = 0
        local startSrcPos, endSrcPos
        local foundStart, foundEnd
        -- check if there are markers at start and end of item. if not, add them.
        local beforeStartSlope, beforeEndSlope

        for j = 0, numStrtchMarkers - 1 do
            local rv, pos, srcpos = r.GetTakeStretchMarker(take, j)
            if pos < startPos then
                beforeStartSlope = r.GetTakeStretchMarkerSlope(take, j)
            end
            if pos < endPos then
                beforeEndSlope = r.GetTakeStretchMarkerSlope(take, j)
            end
            if pos == startPos then
                foundStart = true
                startSrcPos = srcpos
            end
            if OD_Round(pos, 9) == endPos then
                foundEnd = true
                endSrcPos = srcpos
            end
        end

        -- add start and end markers unless found
        if not foundStart then
            local startSm = r.SetTakeStretchMarker(take, -1, startPos)
            local rv, pos, srcpos = r.GetTakeStretchMarker(take, startSm)
            startSrcPos = srcpos
            r.DeleteTakeStretchMarkers(take, startSm)
            if beforeStartSlope then
                r.SetTakeStretchMarkerSlope(take, startSm - 1, beforeStartSlope)
            end
        end
        if not foundEnd then
            local endSm = r.SetTakeStretchMarker(take, -1, endPos)
            local rv, pos, srcpos = r.GetTakeStretchMarker(take, endSm)
            endSrcPos = srcpos
            r.DeleteTakeStretchMarkers(take, endSm)
            if beforeEndSlope then
                r.SetTakeStretchMarkerSlope(take, endSm - 1, beforeEndSlope)
            end
        end

        r.SetActiveTake(savedTake)
        r.SetMediaItemInfo_Value(item, "C_AUTOSTRETCH", tmpItemAutoStretch)
        r.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", tmpBeatAttachMode)

        -- multiply by the take's playrate
        local originalLength = (endSrcPos - startSrcPos)

        -- ignore loops (in case the startpos is not at the first "loop")
        startSrcPos = math.abs(startSrcPos % srclen)
        endSrcPos = startSrcPos + originalLength -- * newTakeplayrate)
        local finalLength = endSrcPos - startSrcPos

        -- for looped items, if longer than one source length, no need for "full" length with all loops
        if finalLength > srclen then
            finalLength = srclen
            endSrcPos = startSrcPos + srclen
        end

        --    r.DeleteTrack(newTrack)

        return startSrcPos, endSrcPos, srclen -- maybe should be finalLength instead? check in regards to playrate
    end

    -- turn off ripple editing
    r.Main_OnCommand(40310, 0) -- set ripple editing per track
    r.Main_OnCommand(41990, 0) -- toggle ripple editing

    local numMediaItems = r.CountMediaItems(0)
    app.mediaFiles = {}
    app.perform.total = numMediaItems
    app.perform.pos = 0
    app.mediaFileCount = 0
    for i = 0, numMediaItems - 1 do
        local mediaItem = r.GetMediaItem(0, i)
        -- local itemStartOffset = r.GetMediaItemInfo_Value(mediaItem,"D_LENGTH")

        -- Get the total number of takes for the media item
        local numTakes = r.GetMediaItemNumTakes(mediaItem)
        app.perform.total = app.perform.total + numTakes - 1
        -- Iterate over each take of the media item
        for j = 0, numTakes - 1 do
            local take = r.GetMediaItemTake(mediaItem, j)

            -- Check if the take is valid and not a MIDI take
            if take and not r.TakeIsMIDI(take) then
                local mediaSource = r.GetMediaItemTake_Source(take)
                local section = false
                local rv, offs, len, rev = r.PCM_Source_GetSectionInfo(mediaSource)
                local sourceParent = r.GetMediaSourceParent(mediaSource)
                local srclen = r.GetMediaSourceLength(mediaSource)
                if sourceParent then
                    mediaSource = sourceParent
                    section = ((len - offs) ~= srclen)
                end

                -- local sourceFile = r.GetMediaSourceFileName(mediaSource)

                if rev then
                    reverseItem(mediaItem)
                end
                -- Check if the media source is valid and has a filename with "WAVE" source type
                local sourceType = r.GetMediaSourceType(mediaSource, "")
                local oc = nil
                local filename = r.GetMediaSourceFileName(mediaSource, "") -- :gsub('/',folderSep())
                local fileExists = OD_FileExists(filename)
                -- log occurance if it's to be minimized
                if fileExists and mediaSource and
                    (OD_HasValue(FORMATS.UNCOMPRESSED, sourceType) or OD_HasValue(FORMATS.LOSSLESS, sourceType) or
                        ((settings.minimizeSourceTypes == MINIMIZE_SOURCE_TYPES.ALL) and
                            OD_HasValue(FORMATS.COMPRESSED, sourceType))) then
                    local sp, ep = getTakeSourcePositions(take, srclen)
                    -- Create a table to store the occurrence information
                    oc = {
                        takeName = r.GetTakeName(take),
                        startTime = sp, -- r.GetMediaItemInfo_Value(mediaItem, "D_POSITION"),
                        endTime = ep, -- r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH") + r.GetMediaItemInfo_Value(mediaItem, "D_POSITION"),
                        newItemPosition = 0, -- Placeholder for the new item's position
                        newItemLength = 0, -- Placeholder for the new item's length
                        newItem = nil,
                        newTake = nil,
                        playrate = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
                        item = mediaItem, -- Reference to the original media item
                        take = take, -- Reference to the original media take
                        placed = false,
                        src = mediaSource,
                        srclen = srclen,
                        newsrclen = 0,
                        rev = rev,
                        section = section
                        -- section_length = len or 0,
                        -- section_offset = offs or 0,
                        -- itemLength = itemLength,
                        -- normalizedItemLength = (itemLength+sp) % math.max(len, srclen),
                    }
                end
                -- Check if the media file entry exists in the mediaFiles table
                if app.mediaFiles[filename] then
                    if oc ~= nil then -- if unsupported format, the occurrence will be nil
                        -- Append the occurrence to the existing entry
                        table.insert(app.mediaFiles[filename].occurrences, oc)
                        if oc.section then
                            app.mediaFiles[filename].hasSection = true
                        end
                    end
                else
                    local fullpath, basename, ext = OD_DissectFilename(filename)
                    local relOrAbsPath, pathIsRelative = OD_GetRelativeOrAbsolutePath(filename, app.projPath)
                    local sourceFileSize = OD_GetFileSize(filename)
                    -- Create a new entry for the media file
                    app.mediaFiles[filename] = {
                        external = not pathIsRelative,
                        video = OD_HasValue(FORMATS.VIDEO, sourceType),
                        status = STATUS.SCANNED,
                        order = app.mediaFileCount,
                        occurrences = {oc},
                        filenameWithPath = filename,
                        fullpath = fullpath,
                        relOrAbsPath = relOrAbsPath,
                        pathIsRelative = pathIsRelative,
                        basename = basename,
                        ext = ext,
                        sourceFileSize = sourceFileSize,
                        newFileSize = nil,
                        hasSection = oc and oc.section or false,
                        srclen = srclen,
                        keep_length = 1,
                        to_process = (oc ~= nil),
                        ignore = (oc == nil),
                        missing = not fileExists,
                        status_info = fileExists and ((oc == nil) and ('%s'):format(sourceType) or '') or 'file missing',
                        newfilename = nil
                    }
                    app.mediaFileCount = app.mediaFileCount + 1
                end
                if app.mediaFiles[filename].hasSection then
                    app.mediaFiles[filename].status_info = 'Has sections'
                    app.mediaFiles[filename].ignore = true
                end
                if app.mediaFiles[filename].ignore then
                    app.mediaFiles[filename].newFileSize = app.mediaFiles[filename].sourceFileSize
                    app.mediaFiles[filename].status = STATUS.IGNORE
                end
                if app.mediaFiles[filename].missing then
                    app.mediaFiles[filename].status = STATUS.ERROR
                end
                app.perform.pos = app.perform.pos + 1
                coroutine.yield('Collecting Takes')
            end
        end
    end
end

-- Create new items to reflect the new occurrences
function minimizeAndApplyMedia()

    local function createTrackForFilename(filename)
        local trackIndex = r.GetNumTracks()
        r.InsertTrackAtIndex(trackIndex, false)
        local track = r.GetTrack(0, trackIndex)
        local basename = filename:match("^.+[\\/](.+)$")
        local no_ext = basename:match("(.+)%.")
        app.mediaFiles[filename].trackName = no_ext .. settings.suffix
        r.GetSetMediaTrackInfo_String(track, "P_NAME", app.mediaFiles[filename].trackName, true)
        return track
    end

    local function addItemsToTrackAndWrapAround(track, fileInfo)
        local splitItems = {}

        -- turn off ripple editing
        r.Main_OnCommand(40310, 0) -- set ripple editing per track
        r.Main_OnCommand(41990, 0) -- toggle ripple editing

        for i, oc in ipairs(fileInfo.occurrences) do

            oc.startpadding = math.min(settings.padding, oc.startTime)
            local ocLength = oc.endTime - oc.startTime + oc.startpadding

            oc.endpadding = math.min(oc.srclen - (oc.startTime + ocLength - oc.startpadding), settings.padding)
            oc.endpadding = math.max(oc.endpadding, 0)
            local ocLength = ocLength + oc.endpadding

            -- Create a new item on the track to reflect the occurrence
            oc.newItem = r.AddMediaItemToTrack(track)
            oc.newTake = r.AddTakeToMediaItem(oc.newItem)

            -- Set the position and length for the new item
            -- r.SetMediaItemPosition(oc.newItem, oc.startTime + oc.section_offset - oc.startpadding, false)
            r.SetMediaItemPosition(oc.newItem, oc.startTime - oc.startpadding, false)
            r.SetMediaItemLength(oc.newItem, ocLength, false)
            r.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN", 0)
            r.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN", 0)
            r.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN_AUTO", -1)
            r.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN_AUTO", -1)
            r.SetMediaItemTake_Source(oc.newTake, oc.src) -- r.GetMediaItemTake_Source(oc.take))
            -- r.SetMediaItemTakeInfo_Value(oc.newTake, "D_STARTOFFS", math.max(0, oc.startTime + oc.section_offset - oc.startpadding))
            r.SetMediaItemTakeInfo_Value(oc.newTake, "D_STARTOFFS", oc.startTime - oc.startpadding)

            -- if longer than media (loop) then wraparound end portion to the start
            if oc.endTime > oc.srclen then
                local splitItem = r.SplitMediaItem(oc.newItem, oc.srclen)
                if splitItem ~= nil then
                    table.insert(splitItems, splitItem)
                    r.SetMediaItemPosition(splitItem, 0, false)
                end
            end

        end
        return splitItems
    end

    local function removeSpaces(track, filename)
        local sections = {}
        local counter = 0
        local currentPos = 0

        local itemCount = r.CountTrackMediaItems(track)
        local emptyItems = {}

        local items = {}
        for i = 0, itemCount - 1 do
            local item = r.GetTrackMediaItem(track, i)
            iteminfo = {
                order = i,
                obj = item,
                startTime = r.GetMediaItemInfo_Value(item, "D_POSITION"),
                length = r.GetMediaItemInfo_Value(item, "D_LENGTH"),
                playrate = r.GetMediaItemInfo_Value(item, "D_PLAYRATE")
            }
            table.insert(items, iteminfo)
        end

        local timeSelEnd
        local keepCounter = 0
        for i, item in OD_PairsByOrder(items) do
            local timeSelStart = currentPos
            timeSelEnd = item.startTime
            -- item.length = item.length * item.playrate
            -- check if there's another item within this time selection
            local skip = false
            if math.abs(timeSelEnd - timeSelStart) < 0.00000001 then
                skip = true
            end
            if item.startTime <= timeSelStart then
                skip = true
            end
            for j, jitem in ipairs(items) do
                if not j == i then
                    -- local jitem = r.GetTrackMediaItem(track, j)
                    if jitem.startTime >= timeSelStart and jitem.startTime <= timeSelEnd then
                        skip = true

                    elseif jitem.startTime + jitem.length >= timeSelStart and jitem.startTime + jitem.length <=
                        timeSelEnd then
                        skip = true

                    elseif jitem.startTime < timeSelStart and jitem.startTime + jitem.length > timeSelStart then
                        skip = true
                    end
                end
            end

            if not skip then
                r.GetSet_LoopTimeRange2(0, true, false, timeSelStart, timeSelEnd, false)
                r.SetEditCurPos(timeSelStart, false, false)
                r.SetOnlyTrackSelected(track)
                r.Main_OnCommand(40142, 0) -- insert empty item
                table.insert(emptyItems, r.GetSelectedMediaItem(0, 0))
                table.insert(sections, {
                    from = timeSelStart / app.mediaFiles[filename].srclen,
                    to = timeSelEnd / app.mediaFiles[filename].srclen,
                    order = counter
                })
                keepCounter = keepCounter +
                                  ((timeSelEnd / app.mediaFiles[filename].srclen) -
                                      (timeSelStart / app.mediaFiles[filename].srclen))
                counter = counter + 1
            end

            if currentPos < item.startTime + item.length then
                currentPos = item.startTime + item.length
            end
        end
        -- add last section
        if currentPos < app.mediaFiles[filename].srclen then
            table.insert(sections, {
                from = currentPos / app.mediaFiles[filename].srclen,
                to = 1,
                order = counter
            })
            keepCounter = keepCounter + (1 - currentPos / app.mediaFiles[filename].srclen)
        end
        r.SelectAllMediaItems(0, false)
        r.Main_OnCommand(40310, 0) -- set ripple editing per track
        for i, item in ipairs(emptyItems) do
            r.SetMediaItemSelected(item, true)
            r.Main_OnCommand(40006, 0) -- delete item
        end
        r.Main_OnCommand(41990, 0) -- toggle ripple editing
        app.mediaFiles[filename].keep_length = 1 - keepCounter
        app.mediaFiles[filename].sections = sections
    end

    local function saveNewPositions(fileInfo)
        for i, oc in ipairs(fileInfo.occurrences) do
            oc.newItemPosition = r.GetMediaItemInfo_Value(oc.newItem, "D_POSITION") + oc.startpadding
        end
    end

    local function trimItems(fileInfo, splitItems)
        -- then trim each object...
        for i, oc in ipairs(fileInfo.occurrences) do
            -- if item was deleted on the vious '40930' action, it is no longer valid
            if r.ValidatePtr2(0, oc.newItem, "MediaItem*") then
                r.SelectAllMediaItems(0, false)
                r.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN", 0)
                r.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN", 0)
                r.SetMediaItemSelected(oc.newItem, true)
                r.Main_OnCommand(40930, 0) -- trim content behind
            end
        end

        -- ...as well as leftovers from the split operation (which are not included in the occurrences collection)
        for i, splitItem in ipairs(splitItems) do
            -- if item was deleted on the previous '40930' action, it is no longer valid
            if r.ValidatePtr2(0, splitItem, "MediaItem*") then
                r.SelectAllMediaItems(0, false)
                r.SetMediaItemInfo_Value(splitItem, "D_FADEINLEN", 0)
                r.SetMediaItemInfo_Value(splitItem, "D_FADEOUTLEN", 0)
                r.SetMediaItemSelected(splitItem, true)
                r.Main_OnCommand(40930, 0) -- trim content behind
            end
        end
    end

    local function glueItems(track)
        -- temporarily remove max file size limitation, if it exists, otherwise glue operation will split every X time
        local maxrecsize_use = select(2, r.get_config_var_string('maxrecsize_use'))
        if maxrecsize_use & 1 == 1 then
            r.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use - 1)
        end

        r.SetOnlyTrackSelected(track)
        r.Main_OnCommand(40421, 0) -- select all items in track
        local _, oldName = r.GetSetMediaItemTakeInfo_String(r.GetMediaItemTake(
            r.GetSelectedMediaItem(0, 0), 0), "P_NAME", "", false)
        r.Main_OnCommand(40362, 0) -- glue items, ignoring time selection
        if maxrecsize_use & 1 then
            r.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use)
        end

        -- check if glue succeeded (maybe cancelled?)
        r.Main_OnCommand(40421, 0) -- select all items in track
        local _, newName = r.GetSetMediaItemTakeInfo_String(r.GetMediaItemTake(
            r.GetSelectedMediaItem(0, 0), 0), "P_NAME", "", false)
        if newName == oldName then
            error('cancelled by glue')
        end
        return r.GetTrackMediaItem(track, 0)
    end

    local function saveTakeStretchMarkers(oc)
        local smrkrs = {}
        local numTakeStretchMarkers = r.GetTakeNumStretchMarkers(oc.take)
        if numTakeStretchMarkers > 0 then
            local itemLength = r.GetMediaItemInfo_Value(oc.item, "D_LENGTH")
            local foundStart = false
            local foundEnd = false
            local startPos = 0 - oc.startpadding
            local endPos = (itemLength + oc.endpadding) * oc.playrate

            endPos = OD_Round(endPos, 9)
            -- check if there are markers at start and end of item. if not, add them.

            for j = 0, numTakeStretchMarkers - 1 do
                local rv, pos, srcpos = r.GetTakeStretchMarker(oc.take, j)
                if pos == startPos then
                    foundStart = true
                end
                if OD_Round(pos, 9) == endPos then
                    foundEnd = true
                end
            end

            -- add start and end markers unless found
            if not foundStart then
                r.SetTakeStretchMarker(oc.take, -1, startPos)
                numTakeStretchMarkers = numTakeStretchMarkers + 1
            end
            if not foundEnd then
                r.SetTakeStretchMarker(oc.take, -1, endPos)
                numTakeStretchMarkers = numTakeStretchMarkers + 1
            end
            -- save markers
            for j = 0, numTakeStretchMarkers - 1 do
                local rv, pos, srcpos = r.GetTakeStretchMarker(oc.take, j)
                if pos >= startPos and pos <= (endPos) then
                    local slope = r.GetTakeStretchMarkerSlope(oc.take, j)
                    -- marker positions get skewed for every loop when replacing the source
                    -- set new source and source offset
                    local src_normal_position = srcpos % oc.srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
                    local srcpos_loops = (srcpos - src_normal_position) / oc.srclen
                    table.insert(smrkrs, {
                        pos = pos,
                        srcpos = srcpos,
                        srcpos_loops = srcpos_loops,
                        src_normal_position = src_normal_position, -- position within the last loop
                        slope = slope
                    })
                end
            end
            -- remove all other stretch markers from item
            r.SelectAllMediaItems(0, false)
            local activeTake = r.GetActiveTake(oc.item)
            r.SetActiveTake(oc.take)
            r.SetMediaItemSelected(oc.item, true)
            r.Main_OnCommand(41844, 0) -- remove all stretch markers in current item
            r.SetActiveTake(activeTake)
        end
        return smrkrs
    end

    local function applyTakeStretchMarkers(oc, smrkrs)
        local delta = oc.newItemPosition - oc.startTime
        if #smrkrs > 0 then
            -- recreate stretch markers
            for j, sm in ipairs(smrkrs) do
                local rv, pos, srcpos = r.GetTakeStretchMarker(oc.take, j - 1)
                r.SetTakeStretchMarker(oc.take, -1, sm.pos,
                    oc.newsrclen * sm.srcpos_loops + sm.src_normal_position + delta)
            end
            for j, sm in ipairs(smrkrs) do
                r.SetTakeStretchMarkerSlope(oc.take, j - 1, sm.slope)
            end
        end
    end

    local function applyTakeMarkers(oc)
        local delta = oc.newItemPosition - oc.startTime
        local numTakeMarkers = r.GetNumTakeMarkers(oc.take)
        for i = 0, numTakeMarkers - 1 do
            local srcpos, name = r.GetTakeMarker(oc.take, i)
            local src_normal_position = srcpos % oc.srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
            local srcpos_loops = (srcpos - src_normal_position) / oc.srclen
            r.SetTakeMarker(oc.take, i, name, oc.newsrclen * srcpos_loops + src_normal_position + delta)
        end
    end

    --     getFileSize for: \\DS1821\Downloads\tmp\Full Recording\Audio Files/02 Tavi'i Itach Yain Mix 1 No Limiter.wav 68709600
    -- getFileSize for: \\DS1821\Downloads\tmp\Full Recording\Audio Files/Tzlil Mechuvan.wav 63352892
    -- getFileSize for: \\DS1821\Downloads\tmp\Full Recording\Audio Files/Mehamerhakim.wav 110689724

    -- getFileSize for: \\DS1821\Downloads\tmp\Full Recording\Audio Files\08-02 Tavi'i Itach Yain Mix 1 No Limiter_m-glued-01.wav 68346862
    -- generateUniqueFilename: file didnt exist. returning it (\\DS1821\Downloads\tmp\Full Recording\Audio Files\02 Tavi'i Itach Yain Mix 1 No Limiter_m.wav)

    -- getFileSize for: \\DS1821\Downloads\tmp\Full Recording\Audio Files\08-Tzlil Mechuvan_m-glued-01.wav 47515372
    -- generateUniqueFilename: file didnt exist. returning it (\\DS1821\Downloads\tmp\Full Recording\Audio Files\Tzlil Mechuvan_m.wav)g

    -- getFileSize for: \\DS1821\Downloads\tmp\Full Recording\Audio Files\08-Mehamerhakim_m-glued-01.wav 83017996
    -- generateUniqueFilename: file didnt exist. returning it (\\DS1821\Downloads\tmp\Full Recording\Audio Files\Mehamerhakim_m.wav)

    -- copyFile: fail at (1): old_file: error, new_file: ok
    --                        old_path: \\DS1821\Downloads\tmp\Full Recording\Audio Files\02 Tavi'i Itach Yain Mix 1 No Limiter_m.wav
    --                        new_path: C:\Users\david\Desktop\Target\Audio Files\02 Tavi'i Itach Yain Mix 1 No Limiter_m.wav

    --                        copyFile: fail at (1): old_file: error, new_file: ok
    --                        old_path: \\DS1821\Downloads\tmp\Full Recording\Audio Files\Tzlil Mechuvan_m.wav
    --                        new_path: C:\Users\david\Desktop\Target\Audio Files\Tzlil Mechuvan_m.wav

    --                        copyFile: fail at (1): old_file: error, new_file: ok
    --                        old_path: \\DS1821\Downloads\tmp\Full Recording\Audio Files\Mehamerhakim_m.wav
    --                        new_path: C:\Users\david\Desktop\Target\Audio Files\Mehamerhakim_m.wav

    local function applyGluedSourceToOriginal(fileInfo, gluedItem)

        local gluedTake = r.GetTake(gluedItem, 0)
        if gluedTake then
            local newSrc = r.GetMediaItemTake_Source(gluedTake)
            local sourceFilename = r.GetMediaSourceFileName(newSrc)
            fileInfo.newFileSize = OD_GetFileSize(sourceFilename)
            -- Rename the source file to the track name
            local path, filename = string.match(sourceFilename, "(.-)([^\\/]-([^%.]+))$")
            local ext = filename:match(".+%.(.+)$")
            local newFilename = path .. fileInfo.trackName .. "." .. ext
            local uniqueName = OD_GenerateUniqueFilename(newFilename)

            -- give time to the file system to refresh 
            local t_point = r.time_precise()
            repeat
            until r.time_precise() - t_point > 0.5

            r.SelectAllMediaItems(0, false)
            r.SetMediaItemSelected(gluedItem, true)

            r.Main_OnCommand(40440, 0) -- set selected media temporarily offline
            local success = moveFile(sourceFilename, uniqueName)
            r.Main_OnCommand(40439, 0) -- online

            -- r.ShowConsoleMsg(('rename \n      %s \n   -> %s\n      '..(success and 'ok' or 'fail')..'\n'):format(sourceFilename,uniqueName))
            -- Update the glued item with the new source file and rebuild peaks
            newSrc = r.PCM_Source_CreateFromFile(uniqueName)
            app.peakOperations[uniqueName] = newSrc
            fileInfo.newfilename = uniqueName
            r.PCM_Source_BuildPeaks(newSrc, 0)

            local newSrcLength = r.GetMediaSourceLength(newSrc)
            for i, oc in ipairs(fileInfo.occurrences) do
                oc.newsrclen = newSrcLength

                -- reset C_BEATATTACHMODE items temporarily for fixing stretch markers
                local tmpItemAutoStretch = r.GetMediaItemInfo_Value(oc.item, "C_AUTOSTRETCH")
                local tmpBeatAttachMode = r.GetMediaItemInfo_Value(oc.item, "C_BEATATTACHMODE")
                r.SetMediaItemInfo_Value(oc.item, "C_AUTOSTRETCH", 0)
                r.SetMediaItemInfo_Value(oc.item, "C_BEATATTACHMODE", 0) -- ]]
                local smrkrs = saveTakeStretchMarkers(oc)

                r.SetMediaItemTake_Source(oc.take, newSrc)
                r.SetMediaItemTakeInfo_Value(oc.take, "D_STARTOFFS", oc.newItemPosition)
                applyTakeStretchMarkers(oc, smrkrs)
                applyTakeMarkers(oc)

                -- apply saved item timbase settings
                r.SetMediaItemInfo_Value(oc.item, "C_AUTOSTRETCH", tmpItemAutoStretch)
                r.SetMediaItemInfo_Value(oc.item, "C_BEATATTACHMODE", tmpBeatAttachMode)

                -- save reverse info
                if oc.rev then
                    reverseItem(oc.item)
                end

                --
            end
        end
    end

    r.SelectAllMediaItems(0, false)
    app.peakOperations = {}
    app.perform.total = app.mediaFileCount
    app.perform.pos = 0
    for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
        if not fileInfo.ignore and not fileInfo.missing then
            app.mediaFiles[filename].status = STATUS.MINIMIZING
            app.perform.pos = app.perform.pos + 1
            coroutine.yield('Minimizing Files')

            local track = createTrackForFilename(filename)
            local splitItems = addItemsToTrackAndWrapAround(track, fileInfo)
            removeSpaces(track, filename)
            saveNewPositions(fileInfo)
            trimItems(fileInfo, splitItems)
            local gluedItem = glueItems(track)
            if gluedItem then
                applyGluedSourceToOriginal(fileInfo, gluedItem)
            end
            r.DeleteTrack(track)

            app.mediaFiles[filename].status = STATUS.MINIMIZED
            coroutine.yield('Minimizing Files')
        end
    end
end

function finalizePeaksBuild()
    local count = 0
    local total = 0
    for k, src in pairs(app.peakOperations) do
        local current = r.PCM_Source_BuildPeaks(src, 1)
        if current == 0 then
            r.PCM_Source_BuildPeaks(src, 2)
        end
        total = total + current
    end
    if count < 100 and total ~= 0 then
        finalizePeaksBuild(app.peakOperations, count + 1)
    end
end

function restore()
    -- restore edit cursor position
    r.SetEditCurPos(app.restore.pos, true, false)
    -- restore saved saving options
    r.SNM_SetIntConfigVar('saveopts', app.restore.saveopts)
    -- restore quality
    r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", app.restore.opencopy_cfgidx, true)
    r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", app.restore.afxfrmt, true)
    r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", app.restore.useprjsrate, true)
    -- delete temporary RPP backup file
    local success, error = os.remove(app.revert.tmpBackupFileName)
end

function revert(cancel)
    -- restore temporary file saved before minimizing and open it
    OD_CopyFile(app.revert.tmpBackupFileName, app.fullProjPath)
    r.Main_openProject("noprompt:" .. app.fullProjPath)

    -- delete files created but not used
    for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
        if fileInfo.newfilename and fileInfo.status ~= STATUS.DONE then
            if OD_FileExists(fileInfo.newfilename) then
                os.remove(fileInfo.newfilename)
            end
        end
    end
    if cancel then
        app.mediaFiles = {}
        app.mediaFileCount = 0
        restore() -- if not cancelled, restore will be called anyway
    end
end

function cancel(msg)
    if msg then 
        app.msg(msg, 'Operation Cancelled')
        if coroutine.isyieldable(app.coPerform) then
            coroutine.yield('Cancelling', 0, 1)
            coroutine.yield('Cancelling', 0, 1)
        end
    end
    -- if app.coPerform then coroutine.close(app.coPerform) end
    app.coPerform = nil
    revert(true)
end

function prepareRestore()
    -- save current edit cursor position
    app.restore.pos = r.GetCursorPosition()
    -- save current autosave options
    app.restore.saveopts = select(2, r.get_config_var_string('saveopts'))
    -- save current glue settings
    _, app.restore.opencopy_cfgidx = r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", 0, false)
    _, app.restore.afxfrmt = r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", "", false)
    app.restore.useprjsrate = r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, false)
end

function setProjPaths()
    app.projPath, app.projFileName, app.fullProjPath, app.projectRecordingPath, app.relProjectRecordingPath =
        getProjectPaths()
end

function setQuality()
    r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", 1, true) -- use custom format
    r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", GLUE_FORMATS_DETAILS[settings.glueFormat].formatString, true) -- set format to selected format from the settings
    r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, true) -- turn off 'use sample rate', which makes the glue operation use the item's sample rate (that's good!)
end

function prepareRevert()
    app.revert.tmpBackupFileName = app.projPath .. select(2, OD_DissectFilename(app.projFileName)) .. '_' ..
                                       r.time_precise() .. '.RPP'
    OD_CopyFile(app.fullProjPath, app.revert.tmpBackupFileName)
end

function disableAutosave()
    local tmpOpts = app.restore.saveopts

    -- disable autosave during operation
    if app.restore.saveopts & 2 == 2 then
        tmpOpts = tmpOpts - 2
    end -- Save to project -> off
    if app.restore.saveopts & 4 == 4 then
        tmpOpts = tmpOpts - 4
    end -- Save to timestamped file in project directory -> off
    if app.restore.saveopts & 8 == 8 then
        tmpOpts = tmpOpts - 8
    end -- Save to timestamped file in additional directory -> off

    -- set disabled saving
    r.SNM_SetIntConfigVar('saveopts', tmpOpts)

end

function createBackupProject()
    r.Main_SaveProject(-1)
    local targetPath = settings.backupDestination .. OD_FolderSep()
    local targetProject = targetPath .. app.projFileName
    OD_CopyFile(app.fullProjPath, targetProject)
    app.perform.total = app.mediaFileCount
    app.perform.pos = 0

    for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
        -- move processed files
        r.RecursiveCreateDirectory(targetPath .. app.relProjectRecordingPath, 0)
        app.perform.pos = app.perform.pos + 1
        if not fileInfo.ignore and not fileInfo.missing then
            fileInfo.status = STATUS.MOVING
            coroutine.yield('Creating backup project')
            local _, newFN, newExt = OD_DissectFilename(fileInfo.newfilename)
            local target = targetPath .. app.relProjectRecordingPath .. OD_FolderSep() .. newFN .. '.' .. newExt
            if moveFile(fileInfo.newfilename, target) then
                fileInfo.status = STATUS.DONE
            else
                fileInfo.status = STATUS.ERROR
                fileInfo.status_info = 'move failed'
            end
        elseif not fileInfo.ignore then -- copy all other files, if in media folder
            if fileInfo.pathIsRelative then
                fileInfo.status = STATUS.COPYING
                coroutine.yield('Creating backup project')
                local target = targetPath .. fileInfo.relOrAbsPath
                if OD_CopyFile(fileInfo.filenameWithPath, target) then
                    fileInfo.status = STATUS.DONE
                else
                    fileInfo.status = STATUS.ERROR
                    fileInfo.status_info = 'copy failed'
                end
            else
                fileInfo.status = STATUS.DONE
            end
        end
        coroutine.yield('Creating backup project')
    end
    -- r.Main_OnCommand(40101, 0)  -- All media media items online
end

function networkedFilesExist()
    if os_is.win then
        for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
            if string.sub(fileInfo.filenameWithPath, 1, 2) == '\\\\' then return true end
        end
    end
    return false
end

function deleteOriginals()
    app.perform.total = app.mediaFileCount
    app.perform.pos = 0
    local stat = settings.deleteOperation == DELETE_OPERATION.MOVE_TO_TRASH and 'Moving originals to trash' or 'Deleting originals'
    local filesToTrashWin = {}
    for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do
        -- delete original files which were replaced by minimized versions
        app.perform.pos = app.perform.pos + 1
        coroutine.yield(stat)
        if not fileInfo.ignore and not fileInfo.missing then
            fileInfo.status = settings.deleteOperation == DELETE_OPERATION.MOVE_TO_TRASH and STATUS.MOVING_TO_TRASH or STATUS.DELETING
            coroutine.yield(stat)
            if os_is.win then
                if settings.deleteOperation ~= DELETE_OPERATION.MOVE_TO_TRASH then
                    r.reduce_open_files(2)  -- windows won't delete/move files that are in use
                    if os.remove(fileInfo.filenameWithPath) then
                        fileInfo.status = STATUS.DONE
                    else
                        fileInfo.status = STATUS.ERROR
                        fileInfo.error = 'delete original failed'
                    end
                else -- if on windows but set to move to trash, we need to first collect filenames and only then send to trash to avoid opening powershell for each file 
                    table.insert(filesToTrashWin, fileInfo.filenameWithPath)
                end
            else
                if (settings.deleteOperation == DELETE_OPERATION.MOVE_TO_TRASH and
                    moveToTrash(fileInfo.filenameWithPath) or os.remove(fileInfo.filenameWithPath)) then
                    fileInfo.status = STATUS.DONE
                else
                    fileInfo.status = STATUS.ERROR
                    fileInfo.error = 'delete original failed'
                end
            end
        elseif not fileInfo.missing then
            fileInfo.status = STATUS.DONE
        end
        coroutine.yield(stat)
    end
    -- if on windows, trash all files at once to avoid powershelling for each file seperately 
    if #filesToTrashWin > 0 then
        r.reduce_open_files(2)  -- windows won't delete/move files that are in use
        moveToTrash(filesToTrashWin)
        for filename, fileInfo in OD_PairsByOrder(app.mediaFiles) do -- verify which files were and were not removed
            if not OD_FileExists(fileInfo.filenameWithPath) then
                fileInfo.status = STATUS.DONE
            else
                fileInfo.status = STATUS.ERROR
                fileInfo.error = 'delete original failed'
            end
        end
    end
end