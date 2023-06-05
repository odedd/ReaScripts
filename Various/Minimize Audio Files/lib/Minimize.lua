-- @noindex

STATUS = {
    IGNORE = 0,
    SCANNED = 1,
    MINIMIZING = 9,
    MINIMIZED = 10,
    MOVING = 50,
    COPYING = 51,
    DONE = 100,
    ERROR = 1000,
}

STATUS_DESCRIPTIONS = {
    [STATUS.IGNORE] = 'Ignore',
    [STATUS.SCANNED] = 'Scanned',
    [STATUS.MINIMIZING] = 'Minimizing',
    [STATUS.MINIMIZED] = 'Minimized',
    [STATUS.MOVING] = 'Moving',
    [STATUS.COPYING] = 'Copying',
    [STATUS.DONE] = 'Done',
    [STATUS.ERROR] = 'Error'
}

FORMATS = {
    COMPRESSED = {'VORBIS', 'OGG', 'OPUS', 'MOGG', 'FLAC', 'MP3', 'WAVPACK'},
    UNCOMPRESSED = {'AIFF', 'WAVE', 'BW64', 'BWF','RF64','SD2', 'WAV', 'W64'},
    INCOMPATIBLE = {'WMV','AVI','MOV', 'EDL','MIDI','MUSICXML', 'MPEG','KAR','QT', 'SYX'},
    SPECIAL = {'REX2'},
    TO_TEST = {'CAF', 'ACID', 'CDDA', 'RAW/PCM', 'RADAR'}
}

function getTakeSourcePositions(take, srclen)
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

    local endPos = math.round(itemLength * takePlayrate, 9)
    local startPos = 0
    local startSrcPos, endSrcPos
    local foundStart, foundEnd
    -- check if there are markers at start and end of item. if not, add them.
    local beforeStartSlope, beforeEndSlope

    for j = 0, numStrtchMarkers - 1 do
        local rv, pos, srcpos = r.GetTakeStretchMarker(take, j)
        if pos < startPos then
            beforeStartSlope = r.GetTakeStretchMarkerSlope(take,j)
        end
        if pos < endPos then
            beforeEndSlope = r.GetTakeStretchMarkerSlope(take,j)
        end
        if pos == startPos then
            foundStart = true
            startSrcPos = srcpos
        end
        if math.round(pos, 9) == endPos then
            foundEnd = true
            endSrcPos = srcpos
        end
    end

    -- add start and end markers unless found
    if not foundStart then
        local startSm = r.SetTakeStretchMarker(take, -1, startPos)
        local rv, pos, srcpos = r.GetTakeStretchMarker(take, startSm)
        startSrcPos = srcpos
        r.DeleteTakeStretchMarkers(take,startSm)
        if beforeStartSlope then reaper.SetTakeStretchMarkerSlope(take,startSm-1,beforeStartSlope) end
    end
    if not foundEnd then
        local endSm = r.SetTakeStretchMarker(take, -1, endPos)
        local rv, pos, srcpos = r.GetTakeStretchMarker(take, endSm)
        endSrcPos = srcpos
        r.DeleteTakeStretchMarkers(take,endSm)
        if beforeEndSlope then reaper.SetTakeStretchMarkerSlope(take,endSm-1,beforeEndSlope) end
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

function reverseItem(item)
    r.SelectAllMediaItems(0, false)
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(41051, 0)
end

-- Collect media files and occurrences
function collectMediaFiles()
    -- turn off ripple editing
    r.Main_OnCommand(40310, 0) -- set ripple editing per track
    r.Main_OnCommand(41990, 0) -- toggle ripple editing

    local projPath, projFileName, fullProjPath, projectRecordingPath = getProjectPaths()
    local numMediaItems = r.CountMediaItems(0)
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
                local sourceFile = r.GetMediaSourceFileName(mediaSource)
                local srclen = r.GetMediaSourceLength(mediaSource)
                if sourceParent then
                    mediaSource = sourceParent
                    section = ((len - offs) ~= srclen)
                end

                if rev then
                    reverseItem(mediaItem)
                end
                -- Check if the media source is valid and has a filename with "WAVE" source type
                local sourceType = r.GetMediaSourceType(mediaSource, "")
                -- reaper.ShowConsoleMsg(sourceType);
                local oc = nil
                local filename = r.GetMediaSourceFileName(mediaSource, "")
                if mediaSource and (has_value(FORMATS.UNCOMPRESSED, sourceType) or ((settings.minimizeSourceTypes == MINIMIZE_SOURCE_TYPES.ALL) and has_value(FORMATS.COMPRESSED, sourceType) )) then
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
                    -- Append the occurrence to the existing entry
                    table.insert(app.mediaFiles[filename].occurrences, oc)
                    if oc.section then
                        app.mediaFiles[filename].hasSection = true
                    end
                else
                    local fullpath, basename, ext = dissectFilename(filename)
                    local relOrAbsPath, pathIsRelative = getRelativeOrAbsolutePath(sourceFile, projPath)
                    -- Create a new entry for the media file
                    app.mediaFiles[filename] = {
                        status = STATUS.SCANNED,
                        order = app.mediaFileCount,
                        filenameWithPath = filename,
                        fullpath = fullpath,
                        relOrAbsPath = relOrAbsPath,
                        pathIsRelative = pathIsRelative,
                        basename = basename,
                        ext = ext,
                        occurrences = {oc},
                        hasSection = oc and oc.section or false,
                        srclen = srclen,
                        keep = 1,
                        to_process = (oc ~= nil),
                        ignore = (oc == nil),
                        status_info = (oc == nil) and ('%s'):format(sourceType) or '',
                        newfilename = nil
                    }
                    app.mediaFileCount = app.mediaFileCount + 1
                end
                if app.mediaFiles[filename].hasSection then 
                    app.mediaFiles[filename].status_info = 'Has sections'
                    app.mediaFiles[filename].ignore = true
                end
                if app.mediaFiles[filename].ignore then 
                    app.mediaFiles[filename].status = STATUS.IGNORE
                end
                app.perform.pos = app.perform.pos + 1
                coroutine.yield('Collecting Items')
            end
        end
    end
end

function removeSpaces(track, filename)
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
    for i, item in pairsByOrder(items) do
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

                elseif jitem.startTime + jitem.length >= timeSelStart and jitem.startTime + jitem.length <= timeSelEnd then
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
            keepCounter = keepCounter + ((timeSelEnd / app.mediaFiles[filename].srclen) - (timeSelStart / app.mediaFiles[filename].srclen))
            counter=counter+1
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
    app.mediaFiles[filename].keep = 1-keepCounter
    app.mediaFiles[filename].sections = sections
end

function saveTakeStretchMarkers(oc)
    local smrkrs = {}
    local numTakeStretchMarkers = r.GetTakeNumStretchMarkers(oc.take)
    -- r.ShowConsoleMsg(numTakeStretchMarkers)
    if numTakeStretchMarkers > 0 then
        local itemLength = r.GetMediaItemInfo_Value(oc.item, "D_LENGTH")
        local foundStart = false
        local foundEnd = false
        local startPos = 0 - oc.startpadding
        local endPos = (itemLength + oc.endpadding) * oc.playrate

        endPos = math.round(endPos, 9)
        -- check if there are markers at start and end of item. if not, add them.

        for j = 0, numTakeStretchMarkers - 1 do
            local rv, pos, srcpos = r.GetTakeStretchMarker(oc.take, j)
            if pos == startPos then
                foundStart = true
            end
            if math.round(pos, 9) == endPos then
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
                src_normal_position = srcpos % oc.srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
                srcpos_loops = (srcpos - src_normal_position) / oc.srclen
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

function applyTakeStretchMarkers(oc, smrkrs)
    local delta = oc.newItemPosition - oc.startTime
    if #smrkrs > 0 then
        -- recreate stretch markers
        for j, sm in ipairs(smrkrs) do
            local rv, pos, srcpos = r.GetTakeStretchMarker(oc.take, j - 1)
            r.SetTakeStretchMarker(oc.take, -1, sm.pos, oc.newsrclen * sm.srcpos_loops + sm.src_normal_position + delta)
        end
        for j, sm in ipairs(smrkrs) do
            r.SetTakeStretchMarkerSlope(oc.take, j - 1, sm.slope)
        end
    end
end

function applyTakeMarkers(oc)
    local delta = oc.newItemPosition - oc.startTime
    local numTakeMarkers = r.GetNumTakeMarkers(oc.take)
    for i = 0, numTakeMarkers - 1 do
        local srcpos, name = r.GetTakeMarker(oc.take, i)
        src_normal_position = srcpos % oc.srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
        srcpos_loops = (srcpos - src_normal_position) / oc.srclen
        r.SetTakeMarker(oc.take, i, name, oc.newsrclen * srcpos_loops + src_normal_position + delta)
    end
end

-- Create new items to reflect the new occurrences
function copyItemsToNewTracks()
    r.SelectAllMediaItems(0, false)
    local peakOperations = {}
    app.perform.total = app.mediaFileCount
    app.perform.pos = 0
    for filename, filenameinfo in pairsByOrder(app.mediaFiles) do
        
        if filenameinfo.ignore == false then
            app.mediaFiles[filename].status = STATUS.MINIMIZING
            app.perform.pos = app.perform.pos + 1
            coroutine.yield('Minimizing Items')
            -- Create a new track for each filename
            local trackIndex = r.GetNumTracks()
            r.InsertTrackAtIndex(trackIndex, false)

            local track = r.GetTrack(0, trackIndex)
            -- r.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            -- Hide the track in MCP
            -- r.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)

            -- local filedir = filename:match(".+[\\/]")
            local basename = filename:match("^.+[\\/](.+)$")
            local no_ext = basename:match("(.+)%.")
            local trackName = no_ext .. settings.suffix
            r.GetSetMediaTrackInfo_String(track, "P_NAME", trackName, true)

            local splitItems = {}
            -- reaper.PreventUIRefresh(1)
            -- turn off ripple editing
            r.Main_OnCommand(40310, 0) -- set ripple editing per track
            r.Main_OnCommand(41990, 0) -- toggle ripple editing

            for i, oc in ipairs(filenameinfo.occurrences) do

                oc.startpadding = math.min(settings.padding, oc.startTime)
                local ocLength = oc.endTime - oc.startTime + oc.startpadding

                oc.endpadding = math.min(oc.srclen - (oc.startTime + ocLength - oc.startpadding), settings.padding)
                oc.endpadding = math.max(oc.endpadding, 0)
                local ocLength = ocLength + oc.endpadding
                -- r.ShowConsoleMsg(oc.srclen)

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
                --[[
            if oc.section then
              
              local splitItem = r.SplitMediaItem(oc.newItem, oc.srclen)
              if splitItem ~= nil then
                -- if original item wraps around to a loop, grab its start,
                --otherwise, get rid of the remainder
                r.ShowConsoleMsg((oc.itemLength + oc.startTime)..'\n')
                
                if (oc.itemLength + oc.startTime)>oc.section_length then 
                  local take = r.GetActiveTake(splitItem)
                  r.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", oc.section_offset)
                  r.SetMediaItemInfo_Value(splitItem, "D_LENGTH", math.min(oc.srclen - oc.section_offset,math.max(oc.itemLength-oc.section_length, oc.normalizedItemLength)))
                  r.SetMediaItemPosition(splitItem, oc.section_offset,false)
                else
                  r.DeleteTrackMediaItem(track,splitItem)
                end
              end
              r.ShowConsoleMsg(oc.normalizedItemLength ..'\n')
              r.ShowConsoleMsg(oc.section_length..'\n')
            end--]]

                -- if longer than media (loop) then wraparound end portion to the start
                if oc.endTime > oc.srclen then
                    local splitItem = r.SplitMediaItem(oc.newItem, oc.srclen)
                    if splitItem ~= nil then
                        table.insert(splitItems, splitItem)
                        r.SetMediaItemPosition(splitItem, 0, false)
                    end
                end

            end
            reaper.PreventUIRefresh(1)
            removeSpaces(track, filename)
            -- trim (leave only one item at any given point in time) and remove fades
           
            -- first copy all positions to the oc object, before the items get deleted
            -- (which is why this has to be done in a separate for loop, otherwise items
            --  might be invalidated by the 40930 action before we get a chance to get their
            --  "new" location)
            for i, oc in ipairs(filenameinfo.occurrences) do
                oc.newItemPosition = r.GetMediaItemInfo_Value(oc.newItem, "D_POSITION") + oc.startpadding
            end

            -- then trim each object...
            for i, oc in ipairs(filenameinfo.occurrences) do
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

            -- temporarily remove max file size limitation, if it exists

            local maxrecsize_use = select(2, r.get_config_var_string('maxrecsize_use'))
            if maxrecsize_use & 1 == 1 then
                r.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use - 1)
            end

            if REAL then
                -- glue
                r.SetOnlyTrackSelected(track)
                r.Main_OnCommand(40421, 0) -- select all items in track
                r.Main_OnCommand(40362, 0) -- glue items, ignoring time selection
            end

            if maxrecsize_use & 1 then
                r.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use)
            end
            if REAL then
                -- apply new source times to existing takes

                local gluedItem = r.GetTrackMediaItem(track, 0)
                if gluedItem then
                    local gluedTake = r.GetTake(gluedItem, 0)
                    if gluedTake then
                        local newSrc = r.GetMediaItemTake_Source(gluedTake)
                        local sourceFilename = r.GetMediaSourceFileName(newSrc)
                        -- Rename the source file to the track name
                        local path, filename = string.match(sourceFilename, "(.-)([^\\/]-([^%.]+))$")
                        local ext = filename:match(".+%.(.+)$")
                        local newFilename = path .. trackName .. "." .. ext
                        local newName = generateUniqueFilename(newFilename)
                        os.rename(sourceFilename, newName)

                        -- Update the glued item with the new source file and rebuild peaks
                        newSrc = r.PCM_Source_CreateFromFile(newName)
                        peakOperations[newName] = newSrc
                        filenameinfo.newfilename = newName
                        r.PCM_Source_BuildPeaks(newSrc, 0)

                        local newSrcLength = r.GetMediaSourceLength(newSrc)
                        for i, oc in ipairs(filenameinfo.occurrences) do
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
            end
            r.DeleteTrack(track)
            reaper.PreventUIRefresh(-1)
            app.mediaFiles[filename].status = STATUS.MINIMIZED
            coroutine.yield('Minimizing Items')
        end
    end
    return peakOperations;
end

function copyItemsToDestination()

end

function finalizePeaksBuild(peakOperations, count)
    if count == nil then
        count = 0
    end
    total = 0
    for k, src in pairs(peakOperations) do
        current = r.PCM_Source_BuildPeaks(src, 1)
        if current == 0 then
            r.PCM_Source_BuildPeaks(src, 2)
        end
        total = total + current
    end
    if count < 100 and total ~= 0 then
        finalizePeaksBuild(peakOperations, count + 1)
    end
end
