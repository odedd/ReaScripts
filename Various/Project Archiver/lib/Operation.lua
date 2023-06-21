-- @noindex

local settings = PA_Settings.settings
YIELD_FREQUENCY = 50

-- * local
local function reverseItem(item)
    OD_LogDebug('-- reverseItem()',nil,1)
    r.SelectAllMediaItems(0, false)
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(41051, 0)
end

-- Scan project recording folder for media files. used by bode CleanMediaFolder() CalculateSavings()
local function getUnusedFilesInRecordingFolder()
    OD_LogDebug('-- getUnusedFilesInRecordingFolder()',nil,1)
    App.ununsedFilesInRecordingFolder = {}
    local function isValidMediaFile(file)
        OD_LogDebug('-- getUnusedFilesInRecordingFolder() -> isValidMediaFile',file,1)
        -- Filter out specific file extensions
        local _, _, extension = OD_DissectFilename(file)
        return OD_HasValue(MEDIA_EXTENSIONS, extension, true) or extension == 'reapeaks'
    end

    -- Scan recording folder
    local fileIndex = 0
    local file = reaper.EnumerateFiles(App.projectRecordingPath, fileIndex)

    App.perform.pos = 0
    while file do
        App.perform.pos = App.perform.pos + 1
        App.perform.total = App.perform.pos
        if (App.perform.pos - 1) % YIELD_FREQUENCY == 0 then
            coroutine.yield('Scanning media folder)')
        end
        file = App.projectRecordingPath .. "/" .. file
        if reaper.file_exists(file) then
            if isValidMediaFile(file) and not App.usedFiles[file] and not App.usedFiles[file:gsub('.reapeaks$', '')] then
                table.insert(App.ununsedFilesInRecordingFolder, { filename = file, size = OD_GetFileSize(file) })
            end
        end
        fileIndex = fileIndex + 1
        file = reaper.EnumerateFiles(App.projectRecordingPath, fileIndex)
    end
end

-- * public
-- Gather media files and occurrences
function GetMediaFiles()
    OD_LogDebug('-- GetMediaFiles()',nil)
    local function getTakeSourcePositions(take, srclen)
        OD_LogDebug('-- GetMediaFiles() -> getTakeSourcePositions()',nil,1)
        -- copy item to new track
        local item = r.GetMediaItemTake_Item(take)
        -- reset item timebase to time, because it screws up taking, but save current setting to re-apply them after copying

        local tmpItemAutoStretch = r.GetMediaItemInfo_Value(item, "C_AUTOSTRETCH")
        local tmpBeatAttachMode = r.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE")
        if settings.minimize then                                 -- no need to do it if not minimizing (wasteful)
            r.SetMediaItemInfo_Value(item, "C_AUTOSTRETCH", 0)
            r.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0) -- ]]
        end
        local savedTake = r.GetActiveTake(item)
        r.SetActiveTake(take)
        -- restore
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
        if settings.minimize then -- no need to do it if not minimizing (wasteful)
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
        end
        r.SetActiveTake(savedTake)
        if settings.minimize then -- no need to do it if not minimizing (wasteful)
            r.SetMediaItemInfo_Value(item, "C_AUTOSTRETCH", tmpItemAutoStretch)
            r.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", tmpBeatAttachMode)
        end
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

    local function addMediaFile(filename, fileType, ignore, fileExists, oc)
        OD_LogDebug('-- GetMediaFiles() -> addMediaFile()',nil,1)
        local fullpath, basename, ext = OD_DissectFilename(filename)
        local relOrAbsFile, relOrAbsPath, pathIsRelative = OD_GetRelativeOrAbsoluteFile(filename,
            App.projPath)
        local sourceFileSize = OD_GetFileSize(filename)
        OD_LogInfo('Adding source ' .. (filename or ''))
        if fileExists == nil then fileExists = OD_FileExists(filename) end
        App.mediaFiles[filename] = {
            order = App.mediaFileCount,
            status = STATUS.SCANNED,
            missing = not fileExists,
            ignore = ignore,
            fileType = fileType,
            filenameWithPath = filename,
            fullpath = fullpath,
            relOrAbsPath = relOrAbsPath,
            basename = basename,
            ext = ext,
            pathIsRelative = pathIsRelative,
            external = not pathIsRelative,
            relOrAbsFile = relOrAbsFile,
            sourceFileSize = sourceFileSize,
            occurrences = { oc },
            hasSection = oc and oc.section or false,
            newFileSize = nil,
            newfilename = nil,
            status_info = '',
            keep_length = 1
        }
        App.scroll = filename
        App.mediaFileCount = App.mediaFileCount + 1
        -- Check if the media file entry exists in the usedFiles table
        if not App.usedFiles[filename] then
            App.usedFiles[filename] = 1
        end
    end

    -- function by MPL
    local function IsRS5K(tr, fxnumber)
        OD_LogDebug('-- GetMediaFiles() -> IsRS5K()',nil,1)
        if not tr then
            return
        end
        local rv, buf = r.TrackFX_GetFXName(tr, fxnumber, '')
        if not rv then
            return
        end
        local rv, buf = r.TrackFX_GetParamName(tr, fxnumber, 3, '')
        if not rv or buf ~= 'Note range start' then
            return
        end
        return true, tr, fxnumber
    end

    local function getMediaFileFromTake(mediaItem, take) -- Check if the take is valid and not a MIDI take
        OD_LogDebug('-- GetMediaFiles() -> getMediaFileFromTake()',nil,1)
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

            if rev then
                reverseItem(mediaItem)
            end
            -- Check if the media source is valid and has a filename with "WAVE" source type
            local sourceType = r.GetMediaSourceType(mediaSource, "")
            local oc = nil
            local filename = r.GetMediaSourceFileName(mediaSource, "") -- :gsub('/',folderSep())
            local fileExists = OD_FileExists(filename)
            -- log occurance if it's to be minimized
            if fileExists and mediaSource then
                local sp, ep
                if settings.minimize then -- no need to do it if not minimizing (wasteful)
                    sp, ep = getTakeSourcePositions(take, srclen)
                end
                -- Create a table to store the occurrence information
                oc = {
                    takeName = r.GetTakeName(take),
                    startTime = sp,      -- r.GetMediaItemInfo_Value(mediaItem, "D_POSITION"),
                    endTime = ep,        -- r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH") + r.GetMediaItemInfo_Value(mediaItem, "D_POSITION"),
                    newItemPosition = 0, -- Placeholder for the new item's position
                    newItemLength = 0,   -- Placeholder for the new item's length
                    newItem = nil,
                    newTake = nil,
                    playrate = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
                    item = mediaItem, -- Reference to the original media item
                    take = take,      -- Reference to the original media take
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
            if App.mediaFiles[filename] then
                if oc ~= nil then -- if unsupported format, the occurrence will be nil
                    -- Append the occurrence to the existing entry
                    table.insert(App.mediaFiles[filename].occurrences, oc)
                    if oc.section then
                        App.mediaFiles[filename].hasSection = true
                    end
                end
            else
                local fileType = FILE_TYPES.AUDIO
                if OD_HasValue(MEDIA_TYPES.VIDEO, sourceType) then
                    fileType = FILE_TYPES.VIDEO
                elseif OD_HasValue(MEDIA_TYPES.SUBPROJECT, sourceType) then
                    fileType = FILE_TYPES.SUBPROJECT
                end
                local ignore = true
                if OD_HasValue(MEDIA_TYPES.UNCOMPRESSED, sourceType) or
                    OD_HasValue(MEDIA_TYPES.LOSSLESS, sourceType) or
                    OD_HasValue(MEDIA_TYPES.SUBPROJECT, sourceType) then
                    ignore = false
                end
                if (settings.minimizeSourceTypes == MINIMIZE_SOURCE_TYPES.ALL) and
                    OD_HasValue(MEDIA_TYPES.COMPRESSED, sourceType) then
                    ignore = false
                end
                addMediaFile(filename, fileType, ignore, fileExists, oc)
                App.mediaFiles[filename].srclen = srclen
                App.mediaFiles[filename].sourceType = sourceType
            end
            if App.mediaFiles[filename].hasSection then
                App.mediaFiles[filename].status_info = 'Has sections'
                App.mediaFiles[filename].ignore = true
            end
            if App.mediaFiles[filename].ignore or not settings.minimize then
                App.mediaFiles[filename].newFileSize = App.mediaFiles[filename].sourceFileSize
                App.mediaFiles[filename].status = STATUS.IGNORE
                App.mediaFiles[filename].status_info = sourceType
            end
            if App.mediaFiles[filename].missing then
                App.mediaFiles[filename].status = STATUS.ERROR
                App.mediaFiles[filename].status_info = 'file missing'
                App.mediaFiles[filename].sourceFileSize = 0
                App.mediaFiles[filename].newFileSize = 0
            end
        end
    end

    local function getFilesFromItems(numMediaItems)
        OD_LogDebug('-- GetMediaFiles() -> getFilesFromItems()',nil,1)
        local YIELD_FREQUENCY = math.min(OD_Round(App.perform.total / 50), YIELD_FREQUENCY)
        numMediaItems = numMediaItems or r.CountMediaItems(0)
        for i = 0, numMediaItems - 1 do
            local mediaItem = r.GetMediaItem(0, i)
            -- local itemStartOffset = r.GetMediaItemInfo_Value(mediaItem,"D_LENGTH")

            -- Get the total number of takes for the media item
            local numTakes = r.GetMediaItemNumTakes(mediaItem)
            App.perform.total = App.perform.total + numTakes - 1
            -- Iterate over each take of the media item
            for j = 0, numTakes - 1 do
                local take = r.GetMediaItemTake(mediaItem, j)

                getMediaFileFromTake(mediaItem, take)

                App.perform.pos = App.perform.pos + 1
                if (App.perform.pos - 1) % YIELD_FREQUENCY == 0 then
                    coroutine.yield('Collecting Takes')
                end
            end
        end
    end

    -- based on funciton by MPL
    local function getFilesFromRS5K()
        OD_LogDebug('-- GetMediaFiles() -> getFilesFromRS5K()',nil,1)
        for i = 1, r.GetNumTracks(0) do
            local tr = r.GetTrack(0, i - 1)
            for fx = 1, r.TrackFX_GetCount(tr) do
                if IsRS5K(tr, fx - 1) then
                    local retval, file_src = r.TrackFX_GetNamedConfigParm(tr, fx - 1, 'FILE0')
                    if App.mediaFiles[file_src] then
                        table.insert(App.mediaFiles[file_src].instances, { track = tr, fxIndex = fx - 1 })
                    else
                        addMediaFile(file_src, FILE_TYPES.RS5K, true)
                        App.mediaFiles[file_src].instances = { { track = tr, fxIndex = fx - 1 } }
                    end
                    App.mediaFiles[file_src].newFileSize = App.mediaFiles[file_src].sourceFileSize
                end
            end
        end
    end

    -- * init
    App.mediaFiles = {}
    App.usedFiles = {} --keeps track of ALL files used in the session for cleaning the media folder
    local numMediaItems = r.CountMediaItems(0)
    App.perform.pos = 0
    App.perform.total = numMediaItems
    App.mediaFileCount = 0

    getFilesFromItems(numMediaItems)
    getFilesFromRS5K()
end

function CollectMedia()
    OD_LogDebug('-- CollectMedia()',nil)
    -- determine which files should be collected:
    local function shouldCollect(fileInfo)
        OD_LogDebug('-- CollectMedia() -> shouldCollect()',fileInfo.filenameWithPath,1)
        --       only if backup, collect all audio files which were ignored
        return (settings.backup and fileInfo.fileType == FILE_TYPES.AUDIO and fileInfo.ignore) or
            -- + if set to collect external audio files, collect them
            (OD_BfCheck(settings.collect, COLLECT.EXTERNAL) and fileInfo.fileType == FILE_TYPES.AUDIO and
                fileInfo.external and fileInfo.ignore)
            -- + if set to collect external video files, collect them (if backup, collect all of them, if not, only collect those that are external)
            or (OD_BfCheck(settings.collect, COLLECT.VIDEO) and fileInfo.fileType == FILE_TYPES.VIDEO and
                (settings.backup or fileInfo.external))
            -- + if set to collect external rs5k files, collect them (if backup, collect all of them, if not, only collect those that are external)
            or (OD_BfCheck(settings.collect, COLLECT.RS5K) and fileInfo.fileType == FILE_TYPES.RS5K and
                (settings.backup or fileInfo.external)) or
            -- + if not minimizing, collect all external audio files, regardless of their "ignore" status
            ((not settings.minimize) and OD_BfCheck(settings.collect, COLLECT.EXTERNAL) and fileInfo.fileType == FILE_TYPES.AUDIO and
                fileInfo.external)
    end

    local function collectFile(fileInfo)
        OD_LogDebug('-- CollectMedia() -> collectFile()',1)
        local targetPath = (App.projPath .. fileInfo.collectBackupTargetPath .. OD_FolderSep()):gsub('//$', '/')
        local targetFileName = targetPath ..
            fileInfo.basename .. (fileInfo.ext and ('.' .. fileInfo.ext) or '')

        local uniqueFilename = OD_GenerateUniqueFilename(targetFileName)
        if not OD_FolderExists(targetPath) then
            App.restore.foldersToDelete = App.restore.foldersToDelete or {}
            table.insert(App.restore.foldersToDelete, targetPath)
        end
        r.RecursiveCreateDirectory(targetPath, 0)
        local success = settings.collectOperation == COLLECT_OPERATION.COPY and
            OD_CopyFile(fileInfo.filenameWithPath, uniqueFilename) or
            OD_MoveFile(fileInfo.filenameWithPath, uniqueFilename)

        return success, uniqueFilename
    end

    local function applyToOriginal(filename, newFilename)
        OD_LogDebug('-- CollectMedia() -> applyToOriginal()',1)
        OD_LogDebug('filename', filename)
        OD_LogDebug('newFilename', newFilename)
        local fileInfo = App.mediaFiles[filename]
        App.usedFiles[filename] = nil
        App.usedFiles[newFilename] = 1
        fileInfo.newfilename = newFilename
        if fileInfo.fileType == FILE_TYPES.RS5K then
            local _, unqBasename, unqExt = OD_DissectFilename(newFilename)
            local uniqueFilenameInBackupDestination
            -- RS5K samples can be set as relative, however they are saved as absolute paths,
            -- so they need to already be set to the backup target location
            if settings.backup then
                local targetPathInBackupDestination = (settings.backupDestination:gsub('\\', '/'):gsub('/$', '') .. OD_FolderSep() .. fileInfo.collectBackupTargetPath .. OD_FolderSep())
                    :gsub('//$', '/')
                uniqueFilenameInBackupDestination = targetPathInBackupDestination ..
                    unqBasename .. (unqExt and ('.' .. unqExt) or '')
            end
            for i, instance in ipairs(fileInfo.instances) do
                r.TrackFX_SetNamedConfigParm(instance.track, instance.fxIndex, 'FILE0',
                    uniqueFilenameInBackupDestination or newFilename)
            end
        else
            local newSrc = r.PCM_Source_CreateFromFile(newFilename)
            if not settings.backup then
                App.peakOperations[newFilename] = newSrc
                r.PCM_Source_BuildPeaks(newSrc, 0)
            end
            for i, oc in ipairs(fileInfo.occurrences) do
                r.SetMediaItemTake_Source(oc.take, newSrc)
                if oc.rev then
                    reverseItem(oc.item)
                end
            end
        end
    end

    App.perform.total = 0
    App.perform.pos = 0
    -- determine_total
    for filename, fileInfo in pairs(App.mediaFiles) do
        fileInfo.shouldCollect = shouldCollect(fileInfo)
        if fileInfo.shouldCollect then
            App.perform.total = App.perform.total + 1
        end
    end

    coroutine.yield('Collecting Files')
    for filename, fileInfo in OD_PairsByOrder(App.mediaFiles) do
        if fileInfo.shouldCollect then
            App.perform.pos = App.perform.pos + 1
            fileInfo.status = STATUS.COLLECTING
            -- if (App.perform.pos - 1) % YIELD_FREQUENCY == 0 then
            App.scroll = filename
            coroutine.yield('Collecting Files')
            -- end

            -- if backing up, should later copy (not move) *internal* files to the backup (leaving originals untouched)
            -- otherwise, should first copy/move(according to setting) them to the current project folder, in order
            -- to get correct relative file references in the RPP, and set them to later MOVE to the backup destination
            -- so they won't be left in the original folder.
            if (settings.backup and not fileInfo.external) then
                if fileInfo.fileType == FILE_TYPES.RS5K then
                    -- the file's folder in the target folder should be the same as it is currently in relation to the project's path
                    fileInfo.collectBackupTargetPath = fileInfo.relOrAbsPath
                        :gsub('\\', '/'):gsub('/$', ''):gsub('^/', '')
                    if fileInfo.collectBackupTargetPath ~= '' then
                        fileInfo.collectBackupTargetPath = fileInfo
                            .collectBackupTargetPath .. OD_FolderSep()
                    end
                    applyToOriginal(filename, fileInfo.filenameWithPath)
                end
                fileInfo.collectBackupOperation = COLLECT_BACKUP_OPERATION.COPY
            else
                -- the file's folder in the target folder should be according to the targetPath setting (or the recording path if targetPath is not set)
                fileInfo.collectBackupTargetPath = (settings.targetPaths[fileInfo.fileType] or App.relProjectRecordingPath)
                    :gsub('\\', '/'):gsub('/$', ''):gsub('^/', '')
                if fileInfo.collectBackupTargetPath ~= '' then
                    fileInfo.collectBackupTargetPath = fileInfo
                        .collectBackupTargetPath .. OD_FolderSep()
                end
                local success, newFileName = collectFile(fileInfo)
                if success then
                    OD_LogInfo('Collection succeeded',newFileName)
                    fileInfo.collectBackupOperation = COLLECT_BACKUP_OPERATION.MOVE
                    applyToOriginal(filename, newFileName)
                else
                    OD_LogError('Collection failed', newFileName)
                    fileInfo.status = STATUS.ERROR
                    fileInfo.status_info = 'collection failed'
                end
            end

            fileInfo.status = STATUS.COLLECTED
        end
    end
end

-- Create new items to reflect the new occurrences
function MinimizeAndApplyMedia()
    OD_LogDebug('-- MinimizeAndApplyMedia()',nil)
    local function createTrackForFilename(filename)
        OD_LogDebug('-- MinimizeAndApplyMedia() -> createTrackForFilename()',filename,1)
        local trackIndex = r.GetNumTracks()
        r.InsertTrackAtIndex(trackIndex, false)
        local track = r.GetTrack(0, trackIndex)
        local basename = filename:match("^.+[\\/](.+)$")
        local no_ext = basename:match("(.+)%.")
        App.mediaFiles[filename].trackName = no_ext .. settings.suffix
        r.GetSetMediaTrackInfo_String(track, "P_NAME", App.mediaFiles[filename].trackName, true)
        return track
    end

    local function addItemsToTrackAndWrapAround(track, fileInfo)
        OD_LogDebug('-- MinimizeAndApplyMedia() -> addItemsToTrackAndWrapAround()',nil,1)
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
        OD_LogDebug('-- MinimizeAndApplyMedia() -> removeSpaces()',nil,1)
        local sections = {}
        local counter = 0
        local currentPos = 0

        local itemCount = r.CountTrackMediaItems(track)
        local emptyItems = {}

        local items = {}
        for i = 0, itemCount - 1 do
            local item = r.GetTrackMediaItem(track, i)
            local iteminfo = {
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
                    from = timeSelStart / App.mediaFiles[filename].srclen,
                    to = timeSelEnd / App.mediaFiles[filename].srclen,
                    order = counter
                })
                keepCounter = keepCounter +
                    ((timeSelEnd / App.mediaFiles[filename].srclen) -
                        (timeSelStart / App.mediaFiles[filename].srclen))
                counter = counter + 1
            end

            if currentPos < item.startTime + item.length then
                currentPos = item.startTime + item.length
            end
        end
        -- add last section
        if currentPos < App.mediaFiles[filename].srclen then
            table.insert(sections, {
                from = currentPos / App.mediaFiles[filename].srclen,
                to = 1,
                order = counter
            })
            keepCounter = keepCounter + (1 - currentPos / App.mediaFiles[filename].srclen)
        end
        r.SelectAllMediaItems(0, false)
        r.Main_OnCommand(40310, 0) -- set ripple editing per track
        for i, item in ipairs(emptyItems) do
            r.SetMediaItemSelected(item, true)
            r.Main_OnCommand(40006, 0) -- delete item
        end
        r.Main_OnCommand(41990, 0)     -- toggle ripple editing
        App.mediaFiles[filename].keep_length = 1 - keepCounter
        App.mediaFiles[filename].sections = sections
    end

    local function saveNewPositions(fileInfo)
        OD_LogDebug('-- MinimizeAndApplyMedia() -> saveNewPositions()',nil,1)
        for i, oc in ipairs(fileInfo.occurrences) do
            oc.newItemPosition = r.GetMediaItemInfo_Value(oc.newItem, "D_POSITION") + oc.startpadding
        end
    end

    local function trimItems(fileInfo, splitItems)
        OD_LogDebug('-- MinimizeAndApplyMedia() -> trimItems()',nil,1)
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
        OD_LogDebug('-- MinimizeAndApplyMedia() -> glueItems()',nil,1)
        -- temporarily remove max file size limitation, if it exists, otherwise glue operation will split every X time
        local maxrecsize_use = select(2, r.get_config_var_string('maxrecsize_use'))
        if maxrecsize_use & 1 == 1 then
            r.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use - 1)
        end

        r.SetOnlyTrackSelected(track)
        r.Main_OnCommand(40421, 0) -- select all items in track
        local _, oldName = r.GetSetMediaItemTakeInfo_String(r.GetMediaItemTake(r.GetSelectedMediaItem(0, 0), 0),
            "P_NAME", "", false)
        r.Main_OnCommand(40362, 0) -- glue items, ignoring time selection
        if maxrecsize_use & 1 then
            r.SNM_SetIntConfigVar('maxrecsize_use', maxrecsize_use)
        end

        -- check if glue succeeded (maybe cancelled?)
        r.Main_OnCommand(40421, 0) -- select all items in track
        local _, newName = r.GetSetMediaItemTakeInfo_String(r.GetMediaItemTake(r.GetSelectedMediaItem(0, 0), 0),
            "P_NAME", "", false)
        if newName == oldName then
            OD_LogInfo('Detected unsuccessful gluing (probably due to user cancelling)')
            error('cancelled by glue')
        end
        return r.GetTrackMediaItem(track, 0)
    end

    local function saveTakeStretchMarkers(oc)
        OD_LogDebug('-- MinimizeAndApplyMedia() -> saveTakeStretchMarkers()',nil,1)
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
                    local src_normal_position = srcpos %
                        oc
                        .srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
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
        OD_LogDebug('-- MinimizeAndApplyMedia() -> applyTakeStretchMarkers()',nil,1)
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
        OD_LogDebug('-- MinimizeAndApplyMedia() -> applyTakeMarkers()',nil,1)
        local delta = oc.newItemPosition - oc.startTime
        local numTakeMarkers = r.GetNumTakeMarkers(oc.take)
        for i = 0, numTakeMarkers - 1 do
            local srcpos, name = r.GetTakeMarker(oc.take, i)
            local src_normal_position = srcpos %
                oc
                .srclen --- think about this. we need to separately get number of loops and remainder (maybe direction too?)
            local srcpos_loops = (srcpos - src_normal_position) / oc.srclen
            r.SetTakeMarker(oc.take, i, name, oc.newsrclen * srcpos_loops + src_normal_position + delta)
        end
    end

    local function applyGluedSourceToOriginal(originalFilename, gluedItem)
        OD_LogDebug('-- MinimizeAndApplyMedia() -> applyGluedSourceToOriginal()',nil,1)
        local fileInfo = App.mediaFiles[originalFilename]
        local gluedTake = r.GetTake(gluedItem, 0)
        if gluedTake then
            local newSrc = r.GetMediaItemTake_Source(gluedTake)
            local sourceFilename = r.GetMediaSourceFileName(newSrc)
            fileInfo.newFileSize = OD_GetFileSize(sourceFilename)
            -- Rename the source file to the track name
            local path, filename = string.match(sourceFilename, "(.-)([^\\/]-([^%.]+))$")
            local ext = filename:match(".+%.(.+)$")
            local newFilename = path .. fileInfo.trackName .. (ext and ("." .. ext) or '')
            local uniqueName = OD_GenerateUniqueFilename(newFilename)

            r.SelectAllMediaItems(0, false)
            r.SetMediaItemSelected(gluedItem, true)

            r.Main_OnCommand(40440, 0) -- set selected media temporarily offline
            local success = OD_MoveFile(sourceFilename, uniqueName)
            r.Main_OnCommand(40439, 0) -- online
            if not success then
                fileInfo.status = STATUS.ERROR
                fileInfo.status_info = 'move minimized version failed'
            else
                -- Update the glued item with the new source file and rebuild peaks

                newSrc = r.PCM_Source_CreateFromFile(uniqueName)
                fileInfo.newfilename = uniqueName
                -- update usedFiles table with the replaced file
                App.usedFiles[originalFilename] = nil
                App.usedFiles[uniqueName] = 1

                if not settings.backup then
                    App.peakOperations[uniqueName] = newSrc
                    r.PCM_Source_BuildPeaks(newSrc, 0)
                end

                -- update stretch markers and take markers
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
    end

    r.SelectAllMediaItems(0, false)
    App.perform.total = App.mediaFileCount
    App.perform.pos = 0
    coroutine.yield('Minimizing Files')
    for filename, fileInfo in OD_PairsByOrder(App.mediaFiles) do
        if not fileInfo.ignore and not fileInfo.missing then
            OD_LogInfo('Processing file',filename)
            App.scroll = filename
            fileInfo.status = STATUS.MINIMIZING
            App.perform.pos = App.perform.pos + 1
            coroutine.yield('Minimizing Files')
            local track = createTrackForFilename(filename)
            local splitItems = addItemsToTrackAndWrapAround(track, fileInfo)
            removeSpaces(track, filename)
            local glueIsSmallerThanOriginal = false
            if OD_HasValue(MEDIA_TYPES.UNCOMPRESSED, fileInfo.sourceType) and GLUE_FORMATS_DETAILS[settings.glueFormat].type == MEDIA_TYPES.LOSSLESS then
                glueIsSmallerThanOriginal = true
            end
            -- if nothing to remove from original file and the glue format will not result in a smaller file size, so there's no need to minimize
            if fileInfo.keep_length > 0.99 and not glueIsSmallerThanOriginal then
                fileInfo.status = STATUS.NOTHING_TO_MINIMIZE
                fileInfo.ignore = true
                fileInfo.newFileSize = fileInfo.sourceFileSize
            else
                saveNewPositions(fileInfo)
                trimItems(fileInfo, splitItems)
                local gluedItem = glueItems(track)
                if gluedItem then
                    applyGluedSourceToOriginal(filename, gluedItem)
                end
                if not fileInfo.status == STATUS.ERROR then fileInfo.status = STATUS.MINIMIZED end
            end
            r.DeleteTrack(track)

            -- coroutine.yield('Minimizing Files')
        else
            OD_LogInfo('Ignoring file',filename)
            OD_LogDebug('fileInfo.ignore',fileInfo.ignore)
            OD_LogDebug('fileInfo.missing',fileInfo.missing)
        end
    end
end

function FinalizePeaksBuild(count)
    OD_LogDebug('-- FinalizePeaksBuild()',count)
    local count = count or 0
    local total = 0
    for k, src in pairs(App.peakOperations or {}) do
        local current = r.PCM_Source_BuildPeaks(src, 1)
        if current == 0 then
            r.PCM_Source_BuildPeaks(src, 2)
        end
        total = total + current
    end
    if count < 100 and total ~= 0 then
        FinalizePeaksBuild(count + 1)
    end
end

function Restore()
    OD_LogDebug('-- Restore()',nil)
    -- restore edit cursor position
    r.SetEditCurPos(App.restore.pos, true, false)
    -- restore saved saving options
    r.SNM_SetIntConfigVar('saveopts', App.restore.saveopts)
    -- restore saved "Save project file references with relative pathnames" setting
    r.SNM_SetIntConfigVar('projrelpath', App.restore.projrelpath)
    -- restore quality
    r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", App.restore.opencopy_cfgidx, true)
    r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", App.restore.afxfrmt, true)
    r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", App.restore.useprjsrate, true)
    -- delete temporary folders
    for i, folder in ipairs(App.restore.foldersToDelete or {}) do
        os.remove(folder)
    end
    -- delete temporary RPP backup file
    local success, error = os.remove(App.revert.tmpBackupFileName)
end

function Revert(cancel)
    OD_LogDebug('-- Revert(cancel)',cancel)
    -- restore temporary file saved before minimizing and open it
    OD_CopyFile(App.revert.tmpBackupFileName, App.fullProjPath)
    -- r.reduce_open_files(2) -- seems ok. might be needed for win, but I tested and I'm pretty sure it's not needed.
    -- delete files created but not used
    for filename, fileInfo in pairs(App.mediaFiles) do
        if fileInfo.newfilename and fileInfo.status ~= STATUS.DONE then
            if OD_FileExists(fileInfo.newfilename) then
                os.remove(fileInfo.newfilename)
            end
        end
    end
    if cancel then
        r.Main_openProject("noprompt:" .. App.fullProjPath)
        App.mediaFiles = {}
        App.usedFiles = {}
        App.mediaFileCount = 0
        Restore() -- if not cancelled, restore will be called anyway
    end
end

function Cancel(msg)
    OD_LogInfo('-- Cancel(msg)',msg)
    if msg then
        App:msg(msg .. T.CANCEL_RELOAD, 'Operation Cancelled')
    end
    -- if app.coPerform then coroutine.close(app.coPerform) end
    App.coPerform = nil
    App.revertCancelOnNextFrame = true -- to allow for the message to appear before loading the project
end

function Prepare()
    OD_LogDebug('-- Prepare()',nil)
    local function setProjPaths()
        OD_LogDebug('-- Prepare() -> setProjPaths()',nil,1)
        App.projPath, App.projFileName, App.fullProjPath, App.projectRecordingPath, App.relProjectRecordingPath =
            OD_GetProjectPaths()
        OD_LogDebug('App.projPath', App.projPath)
        OD_LogDebug('App.projFileName', App.projFileName)
        OD_LogDebug('App.fullProjPath', App.fullProjPath)
        OD_LogDebug('App.projectRecordingPath', App.projectRecordingPath)
        OD_LogDebug('App.relProjectRecordingPath', App.relProjectRecordingPath)
    end
    local function prepareRestore()
        OD_LogDebug('-- Prepare() -> prepareRestore()',nil,1)
        -- save current edit cursor position
        App.restore.pos = r.GetCursorPosition()
        -- save current autosave options
        App.restore.saveopts = select(2, r.get_config_var_string('saveopts'))
        -- save current "Save project file references with relative pathnames" setting
        App.restore.projrelpath = select(2, r.get_config_var_string('projrelpath'))
        -- save current glue settings
        _, App.restore.opencopy_cfgidx = r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", 0, false)
        _, App.restore.afxfrmt = r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", "", false)
        App.restore.useprjsrate = r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, false)
    end
    local function prepareRevert()
        OD_LogDebug('-- Prepare() -> prepareRevert()',nil,1)
        App.revert.tmpBackupFileName = App.projPath .. select(2, OD_DissectFilename(App.projFileName)) .. '_' ..
        r.time_precise() .. '.RPP'
        OD_CopyFile(App.fullProjPath, App.revert.tmpBackupFileName)
    end
    local function prepareSettings()
        OD_LogDebug('-- Prepare() -> prepareSettings()',nil,1)
        local tmpOpts = App.restore.saveopts

        -- disable autosave during operation
        if App.restore.saveopts & 2 == 2 then
            tmpOpts = tmpOpts - 2
        end -- Save to project -> off
        if App.restore.saveopts & 4 == 4 then
            tmpOpts = tmpOpts - 4
        end -- Save to timestamped file in project directory -> off
        if App.restore.saveopts & 8 == 8 then
            tmpOpts = tmpOpts - 8
        end -- Save to timestamped file in additional directory -> off

        -- set disabled saving
        r.SNM_SetIntConfigVar('saveopts', tmpOpts)
        -- set "Save project file references with relative pathnames" enabled
        r.SNM_SetIntConfigVar('projrelpath', 1)
    end
    local function setQuality()
        OD_LogDebug('-- Prepare() -> setQuality()',nil,1)
        r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", 1, true)                                                     -- use custom format
        r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", GLUE_FORMATS_DETAILS[settings.glueFormat].formatString, true) -- set format to selected format from the settings
        r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, true)                                                          -- turn off 'use sample rate', which makes the glue operation use the item's sample rate (that's good!)
    end

    -- first save the project in its current form
    r.Main_SaveProject(-1)
    -- set global project path in app variable
    setProjPaths()
    -- save stuff to restore in any case
    prepareRestore()
    -- save suff to restore in case of error/cancel or if creating a backup
    prepareRevert()
    -- since changes will be made during the process, we don't want the project accidentally saved
    prepareSettings()
    -- set glue quality
    setQuality()
    -- prepare some variables
    App.peakOperations = {}
end

function CreateBackupProject()
    OD_LogDebug('-- CreateBackupProject()',nil)
    r.Main_SaveProject(-1)
    local targetPath = settings.backupDestination .. OD_FolderSep()
    App.backupTargetProject = targetPath .. App.projFileName
    OD_CopyFile(App.fullProjPath, App.backupTargetProject)
    App.perform.total = App.mediaFileCount
    App.perform.pos = 0

    for filename, fileInfo in OD_PairsByOrder(App.mediaFiles) do
        App.scroll = filename
        -- move processed files
        r.RecursiveCreateDirectory(
            targetPath ..
            (fileInfo.collectBackupTargetPath or (fileInfo.pathIsRelative and fileInfo.relOrAbsPath or App.relProjectRecordingPath)),
            0)
        App.perform.pos = App.perform.pos + 1
        if fileInfo.collectBackupOperation == COLLECT_BACKUP_OPERATION.MOVE or (settings.minimize and not fileInfo.ignore and not fileInfo.missing) then
            fileInfo.status = STATUS.MOVING
            coroutine.yield('Creating backup project')
            local _, newFN, newExt = OD_DissectFilename(fileInfo.newfilename)
            local target = targetPath ..
                (fileInfo.collectBackupTargetPath or App.relProjectRecordingPath) ..
                OD_FolderSep() .. newFN .. (newExt and ('.' .. newExt) or '')
            if OD_MoveFile(fileInfo.newfilename, target) then
                fileInfo.status = STATUS.DONE
            else
                fileInfo.status = STATUS.ERROR
                fileInfo.status_info = 'move failed'
            end
        elseif settings.minimize or fileInfo.collectBackupOperation == COLLECT_BACKUP_OPERATION.COPY or (not fileInfo.ignore) then -- copy all other files, if in media folder
            if fileInfo.pathIsRelative then
                fileInfo.status = STATUS.COPYING
                coroutine.yield('Creating backup project')
                local target = targetPath .. fileInfo.relOrAbsFile
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
end

function NetworkedFilesExist()
    OD_LogDebug('-- NetworkedFilesExist()',nil)
    if OS_is.win then
        for filename, fileInfo in pairs(App.mediaFiles) do
            if string.sub(fileInfo.filenameWithPath, 1, 2) == '\\\\' then 
                return OD_LogError('Networked files exist', true)
            end
        end
    end
    return OD_LogInfo('No networked files exist', false)
end

function SubProjectsExist()
    OD_LogDebug('-- SubProjectsExist()',nil)
    for filename, fileInfo in pairs(App.mediaFiles) do
        if fileInfo.fileType == FILE_TYPES.SUBPROJECT then 
            return OD_LogError('Subprojects exist', true)
        end
    end
    return OD_LogInfo('No subprojects exist', false)
end

function DeleteOriginals()
    OD_LogDebug('-- DeleteOriginals()',nil)
    if settings.minimize and settings.deleteMethod ~= DELETE_METHOD.KEEP_IN_FOLDER then
        App.perform.total = App.mediaFileCount

        App.perform.pos = 0
        local stat = settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and 'Moving originals to trash' or
            'Deleting originals'
        local filesToTrashWin = {}
        coroutine.yield(stat)
        for filename, fileInfo in OD_PairsByOrder(App.mediaFiles) do
            -- delete original files which were replaced by minimized versions
            App.perform.pos = App.perform.pos + 1
            App.scroll = filename
            if not fileInfo.external and not fileInfo.ignore and not fileInfo.missing then
                fileInfo.status = settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and STATUS.MOVING_TO_TRASH or
                    STATUS.DELETING
                coroutine.yield(stat)
                if OS_is.win then
                    if settings.deleteMethod ~= DELETE_METHOD.MOVE_TO_TRASH then
                        r.reduce_open_files(2) -- windows won't delete/move files that are in use
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
                    if (settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and
                            OD_MoveToTrash(fileInfo.filenameWithPath) or os.remove(fileInfo.filenameWithPath)) then
                        fileInfo.status = STATUS.DONE
                    else
                        fileInfo.status = STATUS.ERROR
                        fileInfo.error = 'delete original failed'
                    end
                end
            elseif not fileInfo.missing then
                fileInfo.status = STATUS.DONE
                coroutine.yield(stat)
            end
        end

        -- if on windows, trash all files at once to avoid powershelling for each file seperately
        if #filesToTrashWin > 0 then
            coroutine.yield(stat .. ' (might take some time...)')
            r.reduce_open_files(2)                             -- windows won't delete/move files that are in use
            OD_MoveToTrash(filesToTrashWin)
            for filename, fileInfo in pairs(App.mediaFiles) do -- verify which files were and were not removed
                if not OD_FileExists(fileInfo.filenameWithPath) then
                    fileInfo.status = STATUS.DONE
                else
                    fileInfo.status = STATUS.ERROR
                    fileInfo.error = 'delete original failed'
                end
            end
        end
        coroutine.yield(stat)
    end
end

function CleanMediaFolder()
    OD_LogDebug('-- CleanMediaFolder()',nil)
    local function deleteUnusedFiles()
        OD_LogDebug('-- CleanMediaFolder() -> deleteUnusedFiles()',nil,1)
        local stat = settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and 'Moving unused files to trash' or
            'Deleting unused files'

        local filesToTrashWin = {}
        App.perform.total = OD_TableLength(App.ununsedFilesInRecordingFolder)
        App.perform.pos = 0
        for i, file in ipairs(App.ununsedFilesInRecordingFolder) do -- delete original files which were replaced by minimized versions
            App.perform.pos = App.perform.pos + 1
            if (App.perform.pos - 1) % YIELD_FREQUENCY == 0 then
                coroutine.yield(stat)
            end
            if OS_is.win then
                if settings.deleteMethod ~= DELETE_METHOD.MOVE_TO_TRASH then
                    r.reduce_open_files(2) -- windows won't delete/move files that are in use
                    if os.remove(file.filename) then
                        file.deleted = true
                    else
                        file.deleted = false
                    end
                else -- if on windows but set to move to trash, we need to first collect filenames and only then send to trash to avoid opening powershell for each file
                    table.insert(filesToTrashWin, file.filename)
                end
            else
                if settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH then
                    if OD_MoveToTrash(file.filename) then
                        file.deleted = true
                    else
                        file.deleted = false
                    end
                else
                    if os.remove(file.filename) then
                        file.deleted = true
                    else
                        file.deleted = false
                    end
                end
            end
        end

        -- if on windows, trash all files at once to avoid powershelling for each file seperately
        if #filesToTrashWin > 0 then
            coroutine.yield(stat .. ' (might take some time...)')
            r.reduce_open_files(2)                                      -- windows won't delete/move files that are in use
            OD_MoveToTrash(filesToTrashWin)
            for i, file in ipairs(App.ununsedFilesInRecordingFolder) do -- verify which files were and were not removed
                if not OD_FileExists(file.filename) then
                    file.deleted = true
                else
                    file.deleted = false
                end
            end
        end
    end

    if not settings.backup and settings.cleanMediaFolder then
        getUnusedFilesInRecordingFolder()
        deleteUnusedFiles()
    end
end

function KeepActiveTakesOnly()
    OD_LogDebug('-- KeepActiveTakesOnly()',nil)
    -- Count the number of media items
    local itemCount = r.CountMediaItems(0)

    App.perform.total = itemCount
    App.perform.pos = 0
    -- Select all media items
    r.SelectAllMediaItems(0, true)

    -- Deselect the items where "Play all takes" is enabled
    for i = 0, itemCount - 1 do
        App.perform.pos = App.perform.pos + 1
        App.perform.total = App.perform.pos
        if (App.perform.pos - 1) % YIELD_FREQUENCY == 0 then
            coroutine.yield('Scanning takes)')
        end
        local item = r.GetMediaItem(0, i)
        local allTakesPlay = r.GetMediaItemInfo_Value(item, "B_ALLTAKESPLAY")

        if allTakesPlay == 1.0 then
            r.SetMediaItemSelected(item, false)
        end
    end
    reaper.Main_OnCommand(40131, 0) -- Take: Crop to active take in items
end

function CalculateSavings()
    OD_LogDebug('-- CalculateSavings()',nil)
    App.totalSpace = {}
    App.totalSpace.deleted = 0
    App.totalSpace.totalOriginalSize = 0
    App.totalSpace.usedFilesSizeBeforeMinimization = 0
    App.totalSpace.newSize = 0
    App.totalSpace.notMoved = 0

    -- when backing up, media folder size isn't scanned, so it needs to be scanned now to calculate total size
    if settings.backup then getUnusedFilesInRecordingFolder() end
    for i, file in ipairs(App.ununsedFilesInRecordingFolder or {}) do
        if file.deleted then App.totalSpace.deleted = App.totalSpace.deleted + file.size end
        if not App.mediaFiles[file.filename] then
            App.totalSpace.totalOriginalSize = App.totalSpace.totalOriginalSize + file.size
        end
    end

    for filename, fileInfo in pairs(App.mediaFiles) do
        App.totalSpace.totalOriginalSize = App.totalSpace.totalOriginalSize + fileInfo.sourceFileSize
        App.totalSpace.usedFilesSizeBeforeMinimization = App.totalSpace.usedFilesSizeBeforeMinimization +
            fileInfo.sourceFileSize
        App.totalSpace.newSize = App.totalSpace.newSize + fileInfo.newFileSize
    end


    App.totalSpace.saved = App.totalSpace.totalOriginalSize - App.totalSpace.newSize
    App.totalSpace.minimized = App.totalSpace.usedFilesSizeBeforeMinimization - App.totalSpace.newSize
    if settings.backup then App.totalSpace.notMoved = App.totalSpace.saved - App.totalSpace.minimized end
    local msg =
        ('Original media folder size:      %s\n'):format(OD_GetFormattedFileSize(App.totalSpace.totalOriginalSize)) ..
        (settings.minimize and
            ('Minimized files:                 %s\n'):format(OD_GetFormattedFileSize(App.totalSpace.minimized) .. (App.totalSpace.minimized < 0 and '*' or '')) or '') ..
        (settings.backup and
            ('Unused audio in original folder: %s\n'):format(OD_GetFormattedFileSize(App.totalSpace.notMoved)) or '') ..
        ((settings.cleanMediaFolder and not settings.backup) and
            ('Deleted:                         %s\n'):format(OD_GetFormattedFileSize(App.totalSpace.deleted)) or '') ..
        ('New size:                        %s\n'):format(OD_GetFormattedFileSize(App.totalSpace.newSize)) ..
        '\n' ..
        ('Total savings:                   %s\n'):format(OD_GetFormattedFileSize(App.totalSpace.saved)) ..
        ((App.totalSpace.minimized < 0) and ('\n\n* Minimzed size is negative since\ncompressed files were glued together\nas raw PCM files.\n\nTo avoid that, you may select\n"%s" under\n"File types to minimize"'):format(MINIMIZE_SOURCE_TYPES_DESCRIPTIONS[MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS]) or '')

    App:msg(msg, 'Operation complete')
end
