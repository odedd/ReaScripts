-- @description Minimize Audio Files
-- @author Oded Davidov
-- todo (99% ok): figure out playrate (look at Script: X-Raym_Reset take playback rate from snap offset.eel)
-- todo: figure out section
-- todo: GUI
-- todo: cancel
-- todo: check if glue operation failed and stop
-- todo: backup to new project
-- todo: delete replaced files
-- todo: make sure to match glued file format / quality to original
-- todo: figure out MP3s
-- requires sws to remove max file size limitation, as well as for sections
--    if reaper.GetPlayState()&4==4 then;
--        re aper.MB("Eng:\nYou shouldn't record when using this action.\n\n"..
--                  "Rus:\nВы не должны записывать при использовании этого действия"
--        ,"Oops",0);
--    else;
r = reaper

r.ClearConsole()

dofile(select(2, r.get_action_context()):match(".+[\\/]") .. '../../Resources/Common/Common.lua')

if checkPrerequisites({
    reaimgui_version = 9.80,
    sws = true
}) then
    reaper.ShowConsoleMsg('ok')

    local defaultPadding = 1
    local defaultSuffix = "_m"

    function round(num, numDecimalPlaces)
        local mult = 10 ^ (numDecimalPlaces or 0)
        if num >= 0 then
            return math.floor(num * mult + 0.5) / mult
        else
            return math.ceil(num * mult - 0.5) / mult
        end
    end

    function generateUniqueFilename(filename)
        -- Check if the file already exists
        if reaper.file_exists(filename) then
            local counter = 1
            local path, name, ext = string.match(filename, "(.-)([^\\/]-).([^%.]+)$")
            repeat
                counter = counter + 1
                newFilename = path .. name .. "_" .. counter .. "." .. ext
            until not reaper.file_exists(newFilename)
            return newFilename
        else
            return filename
        end
    end

    function getTakeSourcePositions(take)
        -- copy item to new track
        local item = reaper.GetMediaItemTake_Item(take)
        -- reset item timebase to time, because it screws up taking, but save current setting to re-apply them after copying
        local tmpItemAutoStretch = reaper.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH")
        local tmpBeatAttachMode = reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE")
        reaper.SetMediaItemInfo_Value(item, "C_AUTOSTRETCH", 0)
        reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0) -- ]]
        local savedTake = reaper.GetActiveTake(item)
        reaper.SetActiveTake(take)
        reaper.SelectAllMediaItems(0, false)
        reaper.SetMediaItemSelected(item, true)
        reaper.Main_OnCommand(40698, 0) -- copy item
        reaper.SetActiveTake(savedTake)
        local track = reaper.GetMediaItem_Track(item)
        local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        reaper.InsertTrackAtIndex(trackIndex, false)
        local newTrack = reaper.GetTrack(0, trackIndex)
        reaper.SetOnlyTrackSelected(newTrack)
        local newItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

        reaper.SetEditCurPos(newItemPos, false, false)
        reaper.Main_OnCommand(42398, 0) -- paste item

        -- apply saved item timbase settings
        reaper.SetMediaItemInfo_Value(item, "C_AUTOSTRETCH", tmpItemAutoStretch)
        reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", tmpBeatAttachMode)

        -- calculate source positions with regards to stretch markers, by creating "faux" take markers at take's start and end
        local newItem = reaper.GetSelectedMediaItem(0, 0)
        local newItemLength = reaper.GetMediaItemInfo_Value(newItem, "D_LENGTH")

        local newTake = reaper.GetActiveTake(newItem)
        local newTakeplayrate = reaper.GetMediaItemTakeInfo_Value(newTake, "D_PLAYRATE")
        local newTakeSource = reaper.GetMediaItemTake_Source(newTake)
        local sourceParent = reaper.GetMediaSourceParent(newTakeSource)
        if sourceParent then
            newTakeSource = sourceParent
        end
        local newTakeSourceLength = reaper.GetMediaSourceLength(newTakeSource)

        local numStrtchMarkers = reaper.GetTakeNumStretchMarkers(newTake)
        local newSm = reaper.SetTakeStretchMarker(newTake, -1, 0)
        local rv, pos, startpos = reaper.GetTakeStretchMarker(newTake, newSm)

        local endSm = reaper.SetTakeStretchMarker(newTake, -1, newItemLength * newTakeplayrate)
        local rv, pos, endpos = reaper.GetTakeStretchMarker(newTake, endSm)

        -- multiply by the take's playrate
        local originalLength = (endpos - startpos)

        -- ignore loops (in case the startpos is not at the first "loop")
        startpos = math.abs(startpos % newTakeSourceLength)
        endpos = startpos + originalLength -- * newTakeplayrate)
        local finalLength = endpos - startpos

        -- for looped items, if longer than one source length, no need for "full" length with all loops
        if finalLength > newTakeSourceLength then
            finalLength = newTakeSourceLength
            endpos = startpos + newTakeSourceLength
        end

        reaper.DeleteTrack(newTrack)

        return startpos, endpos, newTakeSourceLength -- maybe should be finalLength instead? check in regards to playrate
    end

    function reverseItem(item)
        reaper.SelectAllMediaItems(0, false)
        reaper.SetMediaItemSelected(item, true)
        reaper.Main_OnCommand(41051, 0)
    end

    -- Collect media files and occurrences
    function collectMediaFiles()
        local mediaFiles = {}
        local numMediaItems = reaper.CountMediaItems(0)

        for i = 0, numMediaItems - 1 do
            local mediaItem = reaper.GetMediaItem(0, i)
            -- local itemStartOffset = reaper.GetMediaItemInfo_Value(mediaItem,"D_LENGTH")

            -- Get the total number of takes for the media item
            local numTakes = reaper.GetMediaItemNumTakes(mediaItem)

            -- Iterate over each take of the media item
            for j = 0, numTakes - 1 do
                local take = reaper.GetMediaItemTake(mediaItem, j)

                -- Check if the take is valid and not a MIDI take
                if take and not reaper.TakeIsMIDI(take) then
                    local mediaSource = reaper.GetMediaItemTake_Source(take)
                    local section = false
                    local rv, offs, len, rev = reaper.PCM_Source_GetSectionInfo(mediaSource)
                    local sourceParent = reaper.GetMediaSourceParent(mediaSource)
                    if sourceParent then
                        mediaSource = sourceParent
                        section = ((len - offs) ~= reaper.GetMediaSourceLength(sourceParent))
                    end

                    if rev then
                        reverseItem(mediaItem)
                    end
                    if not section then
                        -- Check if the media source is valid and has a filename with "WAVE" source type
                        local sourceType = reaper.GetMediaSourceType(mediaSource, "")
                        if mediaSource and sourceType == "WAVE" then
                            local filename = reaper.GetMediaSourceFileName(mediaSource, "")
                            local sp, ep, srclen = getTakeSourcePositions(take)
                            -- Create a table to store the occurrence information
                            local oc = {
                                takeName = reaper.GetTakeName(take),
                                startTime = sp, -- reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION"),
                                endTime = ep, -- reaper.GetMediaItemInfo_Value(mediaItem, "D_LENGTH") + reaper.GetMediaItemInfo_Value(mediaItem, "D_POSITION"),
                                newItemPosition = 0, -- Placeholder for the new item's position
                                newItemLength = 0, -- Placeholder for the new item's length
                                newItem = nil,
                                newTake = nil,
                                playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
                                item = mediaItem, -- Reference to the original media item
                                take = take, -- Reference to the original media take
                                placed = false,
                                src = mediaSource,
                                srclen = srclen,
                                newsrclen = 0,
                                rev = rev
                                -- section = section,
                                -- section_length = len or 0,
                                -- section_offset = offs or 0,
                                -- itemLength = itemLength,
                                -- normalizedItemLength = (itemLength+sp) % math.max(len, srclen),

                            }
                            -- Check if the media file entry exists in the mediaFiles table
                            if mediaFiles[filename] then
                                -- Append the occurrence to the existing entry
                                table.insert(mediaFiles[filename], oc)
                            else
                                -- Create a new entry for the media file
                                mediaFiles[filename] = {oc}
                            end
                        end
                    else
                        reaper.ShowConsoleMsg('Items with not supported')
                    end
                end
            end
        end
        return mediaFiles
    end

    function removeSpaces(track)

        local currentPos = 0

        local itemCount = reaper.CountTrackMediaItems(track)
        local emptyItems = {}

        local items = {}
        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            iteminfo = {
                obj = item,
                startTime = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
                length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
                playrate = reaper.GetMediaItemInfo_Value(item, "D_PLAYRATE")
            }
            table.insert(items, iteminfo)
        end

        for i, item in ipairs(items) do
            local timeSelStart = currentPos
            local timeSelEnd = item.startTime
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
                    -- local jitem = reaper.GetTrackMediaItem(track, j)
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
                reaper.GetSet_LoopTimeRange2(0, true, false, timeSelStart, timeSelEnd, false)
                reaper.SetEditCurPos(timeSelStart, false, false)
                reaper.SetOnlyTrackSelected(track)
                reaper.Main_OnCommand(40142, 0) -- insert empty item
                table.insert(emptyItems, reaper.GetSelectedMediaItem(0, 0))
            end

            if currentPos < item.startTime + item.length then
                currentPos = item.startTime + item.length
            end
        end
        reaper.SelectAllMediaItems(0, false)
        reaper.Main_OnCommand(40310, 0) -- set ripple editing per track
        for i, item in ipairs(emptyItems) do
            reaper.SetMediaItemSelected(item, true)
            reaper.Main_OnCommand(40006, 0) -- delete item
        end
        reaper.Main_OnCommand(41990, 0) -- toggle ripple editing
    end

    function saveTakeStretchMarkers(oc)
        local smrkrs = {}
        local numTakeStretchMarkers = reaper.GetTakeNumStretchMarkers(oc.take)
        -- reaper.ShowConsoleMsg(numTakeStretchMarkers)
        if numTakeStretchMarkers > 0 then
            local itemLength = reaper.GetMediaItemInfo_Value(oc.item, "D_LENGTH")
            local foundStart = false
            local foundEnd = false
            local startPos = 0 - oc.startpadding
            local endPos = (itemLength + oc.endpadding) * oc.playrate

            endPos = round(endPos, 9)
            -- check if there are markers at start and end of item. if not, add them.

            for j = 0, numTakeStretchMarkers - 1 do
                local rv, pos, srcpos = reaper.GetTakeStretchMarker(oc.take, j)
                if pos == startPos then
                    foundStart = true
                end
                if round(pos, 9) == endPos then
                    foundEnd = true
                end

            end

            -- add start and end markers unless found
            if not foundStart then
                reaper.SetTakeStretchMarker(oc.take, -1, startPos)
                numTakeStretchMarkers = numTakeStretchMarkers + 1
            end
            if not foundEnd then
                reaper.SetTakeStretchMarker(oc.take, -1, endPos)
                numTakeStretchMarkers = numTakeStretchMarkers + 1
            end
            -- save markers
            for j = 0, numTakeStretchMarkers - 1 do
                local rv, pos, srcpos = reaper.GetTakeStretchMarker(oc.take, j)
                if pos >= startPos and pos <= (endPos) then
                    local slope = reaper.GetTakeStretchMarkerSlope(oc.take, j)
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
            reaper.SelectAllMediaItems(0, false)
            local activeTake = reaper.GetActiveTake(oc.item)
            reaper.SetActiveTake(oc.take)
            reaper.SetMediaItemSelected(oc.item, true)
            reaper.Main_OnCommand(41844, 0) -- remove all stretch markers in current item
            reaper.SetActiveTake(activeTake)
        end
        return smrkrs
    end

    function applyTakeStretchMarkers(oc, smrkrs)
        local delta = oc.newItemPosition - oc.startTime
        if #smrkrs > 0 then
            -- recreate stretch markers
            for j, sm in ipairs(smrkrs) do
                local rv, pos, srcpos = reaper.GetTakeStretchMarker(oc.take, j - 1)
                reaper.SetTakeStretchMarker(oc.take, -1, sm.pos,
                    oc.newsrclen * sm.srcpos_loops + sm.src_normal_position + delta)
            end
            for j, sm in ipairs(smrkrs) do
                reaper.SetTakeStretchMarkerSlope(oc.take, j - 1, sm.slope)
            end
        end
    end

    function applyTakeMarkers(oc)
        local delta = oc.newItemPosition - oc.startTime
        local numTakeMarkers = reaper.GetNumTakeMarkers(oc.take)
        for i = 0, numTakeMarkers - 1 do
            local srcpos, name = reaper.GetTakeMarker(oc.take, i)
            src_normal_position = srcpos % oc.srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
            srcpos_loops = (srcpos - src_normal_position) / oc.srclen
            reaper.SetTakeMarker(oc.take, i, name, oc.newsrclen * srcpos_loops + src_normal_position + delta)
        end
    end

    -- Create new items to reflect the new occurrences
    function copyItemsToNewTracks(mediaFiles, padding)
        reaper.SelectAllMediaItems(0, false)
        padding = padding or defaultPadding
        local peakOperations = {}

        for filename, occurrences in pairs(mediaFiles) do
            -- Create a new track for each filename
            local trackIndex = reaper.GetNumTracks()
            reaper.InsertTrackAtIndex(trackIndex, false)

            local track = reaper.GetTrack(0, trackIndex)
            -- reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            -- Hide the track in MCP
            -- reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)

            -- local filedir = filename:match(".+[\\/]")
            local basename = filename:match("^.+[\\/](.+)$")
            local no_ext = basename:match("(.+)%.")
            local trackName = no_ext .. defaultSuffix
            reaper.GetSetMediaTrackInfo_String(track, "P_NAME", trackName, true)

            local splitItems = {}

            -- turn off ripple editing
            reaper.Main_OnCommand(40310, 0) -- set ripple editing per track
            reaper.Main_OnCommand(41990, 0) -- toggle ripple editing

            for i, oc in ipairs(occurrences) do

                oc.startpadding = math.min(padding, oc.startTime)
                local ocLength = oc.endTime - oc.startTime + oc.startpadding

                oc.endpadding = math.min(oc.srclen - (oc.startTime + ocLength - oc.startpadding), padding)
                oc.endpadding = math.max(oc.endpadding, 0)
                local ocLength = ocLength + oc.endpadding
                -- reaper.ShowConsoleMsg(oc.srclen)

                -- Create a new item on the track to reflect the occurrence
                oc.newItem = reaper.AddMediaItemToTrack(track)
                oc.newTake = reaper.AddTakeToMediaItem(oc.newItem)

                -- Set the position and length for the new item
                -- reaper.SetMediaItemPosition(oc.newItem, oc.startTime + oc.section_offset - oc.startpadding, false)
                reaper.SetMediaItemPosition(oc.newItem, oc.startTime - oc.startpadding, false)
                reaper.SetMediaItemLength(oc.newItem, ocLength, false)
                reaper.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN", 0)
                reaper.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN", 0)
                reaper.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN_AUTO", -1)
                reaper.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN_AUTO", -1)
                reaper.SetMediaItemTake_Source(oc.newTake, oc.src) -- reaper.GetMediaItemTake_Source(oc.take))
                -- reaper.SetMediaItemTakeInfo_Value(oc.newTake, "D_STARTOFFS", math.max(0, oc.startTime + oc.section_offset - oc.startpadding))
                reaper.SetMediaItemTakeInfo_Value(oc.newTake, "D_STARTOFFS", oc.startTime - oc.startpadding)
                --[[
            if oc.section then
              
              local splitItem = reaper.SplitMediaItem(oc.newItem, oc.srclen)
              if splitItem ~= nil then
                -- if original item wraps around to a loop, grab its start,
                --otherwise, get rid of the remainder
                reaper.ShowConsoleMsg((oc.itemLength + oc.startTime)..'\n')
                
                if (oc.itemLength + oc.startTime)>oc.section_length then 
                  local take = reaper.GetActiveTake(splitItem)
                  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", oc.section_offset)
                  reaper.SetMediaItemInfo_Value(splitItem, "D_LENGTH", math.min(oc.srclen - oc.section_offset,math.max(oc.itemLength-oc.section_length, oc.normalizedItemLength)))
                  reaper.SetMediaItemPosition(splitItem, oc.section_offset,false)
                else
                  reaper.DeleteTrackMediaItem(track,splitItem)
                end
              end
              reaper.ShowConsoleMsg(oc.normalizedItemLength ..'\n')
              reaper.ShowConsoleMsg(oc.section_length..'\n')
            end--]]

                -- if longer than media (loop) then wraparound end portion to the start
                if oc.endTime > oc.srclen then
                    local splitItem = reaper.SplitMediaItem(oc.newItem, oc.srclen)
                    if splitItem ~= nil then
                        table.insert(splitItems, splitItem)
                        reaper.SetMediaItemPosition(splitItem, 0, false)
                    end
                end

            end

            removeSpaces(track)
            -- trim (leave only one item at any given point in time) and remove fades

            -- first copy all positions to the oc object, before the items get deleted
            -- (which is why this has to be done in a separate for loop, otherwise items
            --  might be invalidated by the 40930 action before we get a chance to get their
            --  "new" location)
            for i, oc in ipairs(occurrences) do
                oc.newItemPosition = reaper.GetMediaItemInfo_Value(oc.newItem, "D_POSITION") + oc.startpadding
            end

            -- then trim each object...
            for i, oc in ipairs(occurrences) do
                -- if item was deleted on the previous '40930' action, it is no longer valid
                if reaper.ValidatePtr2(0, oc.newItem, "MediaItem*") then
                    reaper.SelectAllMediaItems(0, false)
                    reaper.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN", 0)
                    reaper.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN", 0)
                    reaper.SetMediaItemSelected(oc.newItem, true)
                    reaper.Main_OnCommand(40930, 0) -- trim content behind
                end
            end

            -- ...as well as leftovers from the split operation (which are not included in the occurrences collection)
            for i, splitItem in ipairs(splitItems) do
                -- if item was deleted on the previous '40930' action, it is no longer valid
                if reaper.ValidatePtr2(0, splitItem, "MediaItem*") then
                    reaper.SelectAllMediaItems(0, false)
                    reaper.SetMediaItemInfo_Value(splitItem, "D_FADEINLEN", 0)
                    reaper.SetMediaItemInfo_Value(splitItem, "D_FADEOUTLEN", 0)
                    reaper.SetMediaItemSelected(splitItem, true)
                    reaper.Main_OnCommand(40930, 0) -- trim content behind
                end
            end

            -- temporarily remove max file size limitation, if it exists

            local maxrecsize_use = select(2, reaper.get_config_var_string('maxrecsize_use'))
            if maxrecsize_use & 1 == 1 then
                reaper.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use - 1)
            end

            -- glue
            reaper.SetOnlyTrackSelected(track)
            reaper.Main_OnCommand(40421, 0) -- select all items in track
            reaper.Main_OnCommand(40362, 0) -- glue items, ignoring time selection
            if maxrecsize_use & 1 then
                reaper.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use)
            end

            -- apply new source times to existing takes

            local gluedItem = reaper.GetTrackMediaItem(track, 0)
            if gluedItem then
                local gluedTake = reaper.GetTake(gluedItem, 0)
                if gluedTake then
                    local newSrc = reaper.GetMediaItemTake_Source(gluedTake)
                    local sourceFilename = reaper.GetMediaSourceFileName(newSrc)
                    -- Rename the source file to the track name
                    local path, filename = string.match(sourceFilename, "(.-)([^\\/]-([^%.]+))$")
                    local ext = filename:match(".+%.(.+)$")
                    local newFilename = path .. trackName .. "." .. ext
                    local newName = generateUniqueFilename(newFilename)
                    os.rename(sourceFilename, newName)

                    -- Update the glued item with the new source file and rebuild peaks
                    newSrc = reaper.PCM_Source_CreateFromFile(newName)
                    peakOperations[newName] = newSrc
                    reaper.PCM_Source_BuildPeaks(newSrc, 0)

                    local newSrcLength = reaper.GetMediaSourceLength(newSrc)
                    for i, oc in ipairs(occurrences) do
                        oc.newsrclen = newSrcLength

                        -- reset C_BEATATTACHMODE items temporarily for fixing stretch markers
                        local tmpItemAutoStretch = reaper.GetMediaItemInfo_Value(oc.item, "C_AUTOSTRETCH")
                        local tmpBeatAttachMode = reaper.GetMediaItemInfo_Value(oc.item, "C_BEATATTACHMODE")
                        reaper.SetMediaItemInfo_Value(oc.item, "C_AUTOSTRETCH", 0)
                        reaper.SetMediaItemInfo_Value(oc.item, "C_BEATATTACHMODE", 0) -- ]]
                        local smrkrs = saveTakeStretchMarkers(oc)

                        reaper.SetMediaItemTake_Source(oc.take, newSrc)
                        reaper.SetMediaItemTakeInfo_Value(oc.take, "D_STARTOFFS", oc.newItemPosition)
                        applyTakeStretchMarkers(oc, smrkrs)
                        applyTakeMarkers(oc)

                        -- apply saved item timbase settings
                        reaper.SetMediaItemInfo_Value(oc.item, "C_AUTOSTRETCH", tmpItemAutoStretch)
                        reaper.SetMediaItemInfo_Value(oc.item, "C_BEATATTACHMODE", tmpBeatAttachMode)

                        -- save reverse info
                        if oc.rev then
                            reverseItem(oc.item)
                        end

                        --
                    end
                end
            end

            reaper.DeleteTrack(track)

        end
        return peakOperations;
    end

    function finalizePeaksBuild(peakOperations, count)
        if count == nil then
            count = 0
        end
        total = 0
        for k, src in pairs(peakOperations) do
            current = reaper.PCM_Source_BuildPeaks(src, 1)
            if current == 0 then
                reaper.PCM_Source_BuildPeaks(src, 2)
            end
            total = total + current
        end
        if count < 100 and total ~= 0 then
            finalizePeaksBuild(peakOperations, count + 1)
        end
    end

    reaper.Undo_BeginBlock() -- Begining of the undo block. Leave it at the top of your main function.

    -- Execute the script

    local pos = reaper.GetCursorPosition()

    local mediaFiles = collectMediaFiles()

    local peakOperations = copyItemsToNewTracks(mediaFiles)

    reaper.SetEditCurPos(pos, true, false)

    finalizePeaksBuild(peakOperations)

    reaper.Undo_EndBlock("Minimize Audio Files", 0) -- Begining of the undo block. Leave it at the top of your main function.

end