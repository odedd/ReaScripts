-- @noindex

local settings = PA_Settings.current
YIELD_FREQUENCY = 50
Op = {}
-- * local
local function reverseItem(item)
    Op.app.logger:logDebug('-- reverseItem()', nil, 1)
    r.SelectAllMediaItems(0, false)
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(41051, 0)
end

-- Scan project recording folder for media files. used by bode CleanMediaFolder() CalculateSavings()
local function getUnusedFilesInRecordingFolder()
    Op.app.logger:logDebug('-- getUnusedFilesInRecordingFolder()', nil, 1)
    Op.app.ununsedFilesInRecordingFolder = {}
    local function isValidMediaFile(file)
        Op.app.logger:logDebug('-- getUnusedFilesInRecordingFolder() -> isValidMediaFile', file, 1)
        -- Filter out specific file extensions
        local _, _, extension = OD_DissectFilename(file)
        local valid = OD_HasValue(MEDIA_EXTENSIONS, extension, true) or extension == 'reapeaks'
        Op.app.logger:logDebug('isValidMediaFile', valid)
        return valid
    end

    -- Scan recording folder
    local fileIndex = 0
    local file = reaper.EnumerateFiles(Op.app.projectRecordingPath, fileIndex)

    Op.app.perform.pos = 0
    while file do
        Op.app.perform.pos = Op.app.perform.pos + 1
        Op.app.perform.total = Op.app.perform.pos
        if (Op.app.perform.pos - 1) % YIELD_FREQUENCY == 0 then
            coroutine.yield('Scanning media folder)')
        end
        file = Op.app.projectRecordingPath .. "/" .. file
        if reaper.file_exists(file) then
            if isValidMediaFile(file) and not Op.app.usedFiles[file] and not Op.app.usedFiles[file:gsub('%.reapeaks$', '')] then
                table.insert(Op.app.ununsedFilesInRecordingFolder, { filename = file, size = OD_GetFileSize(file) })
            end
        end
        fileIndex = fileIndex + 1
        file = reaper.EnumerateFiles(Op.app.projectRecordingPath, fileIndex)
    end
end

-- * public
-- Gather media files and occurrences
function GetMediaFiles()
    Op.app.logger:logInfo('-- GetMediaFiles()', nil)
    local function getTakeSourcePositions(take, srclen)
        Op.app.logger:logDebug('-- GetMediaFiles() -> getTakeSourcePositions()', nil, 1)
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

    local function addMediaFile(filename, fileType, ignore, fileExists, oc, sourceType)
        Op.app.logger:logDebug('-- GetMediaFiles() -> addMediaFile()', nil, 1)
        local fullpath, basename, ext = OD_DissectFilename(filename)
        local relOrAbsFile, relOrAbsPath, pathIsRelative = OD_GetRelativeOrAbsoluteFile(filename,
            Op.app.projPath)
        local sourceFileSize = OD_GetFileSize(filename)
        Op.app.logger:logInfo('Adding source ' .. (filename or ''))
        assert(basename ~= nil, 'Media filename could not be parsed')
        if fileExists == nil then fileExists = OD_FileExists(filename) end
        if not Op.app.mediaFiles[filename] then Op.app.mediaFileCount = Op.app.mediaFileCount + 1 end
        Op.app.mediaFiles[filename] = {
            order = Op.app.mediaFileCount,
            status = STATUS.SCANNED,
            missing = not fileExists,
            ignore = ignore,
            fileType = fileType,
            filenameWithPath = filename,
            fullpath = fullpath,
            relOrAbsPath = relOrAbsPath,
            basename = basename,
            filenameWithoutPath = (basename and (basename .. (ext and ('.' .. ext) or '')) or nil),
            ext = ext,
            pathIsRelative = pathIsRelative,
            external = not pathIsRelative,
            relOrAbsFile = relOrAbsFile,
            sourceFileSize = fileExists and sourceFileSize or 0,
            occurrences = { oc },
            hasSection = oc and oc.section or false,
            newFileSize = nil,
            newfilename = nil,
            status_info = '',
            keep_length = 1
        }

        if Op.app.mediaFiles[filename].hasSection then
            Op.app.mediaFiles[filename].status_info = 'Has sections'
            Op.app.mediaFiles[filename].ignore = true
        end
        if Op.app.mediaFiles[filename].ignore or not settings.minimize then
            Op.app.mediaFiles[filename].newFileSize = Op.app.mediaFiles[filename].sourceFileSize
            Op.app.mediaFiles[filename].status = STATUS.IGNORE
            Op.app.mediaFiles[filename].status_info = sourceType or ""
        end
        if Op.app.mediaFiles[filename].missing then
            Op.app.mediaFiles[filename].status = STATUS.ERROR
            Op.app.mediaFiles[filename].status_info = 'file missing'
            Op.app.mediaFiles[filename].sourceFileSize = 0
            Op.app.mediaFiles[filename].newFileSize = 0
        end


        Op.app.scroll = filename
        -- Check if the media file entry exists in the usedFiles table
        if not Op.app.usedFiles[filename] then
            Op.app.usedFiles[filename] = 1
        end
    end

    -- function by MPL
    local function IsRS5K(tr, fxnumber)
        Op.app.logger:logDebug('-- GetMediaFiles() -> IsRS5K()', nil, 1)
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
        Op.app.logger:logDebug('-- GetMediaFiles() -> getMediaFileFromTake()', nil, 1)
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
            if sourceType ~= 'EMPTY' and sourceType ~= 'CLICK' then
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
                if Op.app.mediaFiles[filename] then
                    if oc ~= nil then -- if unsupported format, the occurrence will be nil
                        -- Append the occurrence to the existing entry
                        table.insert(Op.app.mediaFiles[filename].occurrences, oc)
                        if oc.section then
                            Op.app.mediaFiles[filename].hasSection = true
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
                    addMediaFile(filename, fileType, ignore, fileExists, oc, sourceType)
                    Op.app.mediaFiles[filename].srclen = srclen
                    Op.app.mediaFiles[filename].sourceType = sourceType
                end
            end
        end
    end

    local function getFilesFromItems(numMediaItems)
        Op.app.logger:logDebug('-- GetMediaFiles() -> getFilesFromItems()', nil, 1)
        local YIELD_FREQUENCY = math.min(OD_Round(Op.app.perform.total / 50), YIELD_FREQUENCY)
        numMediaItems = numMediaItems or r.CountMediaItems(0)
        for i = 0, numMediaItems - 1 do
            local mediaItem = r.GetMediaItem(0, i)
            -- local itemStartOffset = r.GetMediaItemInfo_Value(mediaItem,"D_LENGTH")

            -- Get the total number of takes for the media item
            local numTakes = r.GetMediaItemNumTakes(mediaItem)
            Op.app.perform.total = Op.app.perform.total + numTakes - 1
            -- Iterate over each take of the media item
            for j = 0, numTakes - 1 do
                local take = r.GetMediaItemTake(mediaItem, j)

                getMediaFileFromTake(mediaItem, take)

                Op.app.perform.pos = Op.app.perform.pos + 1
                if (Op.app.perform.pos - 1) % YIELD_FREQUENCY == 0 then
                    coroutine.yield('Collecting Takes')
                end
            end
        end
    end
    -- based on funciton by MPL
    local function getFilesFromRS5K()
        Op.app.logger:logDebug('-- GetMediaFiles() -> getFilesFromRS5K()', nil, 1)
        for i = 0, r.GetNumTracks(0) - 1 do
            local tr = r.GetTrack(0, i)
            for fx = 0, r.TrackFX_GetCount(tr) - 1 do
                if IsRS5K(tr, fx) then
                    local retval, file_src = r.TrackFX_GetNamedConfigParm(tr, fx, 'FILE0')
                    if Op.app.mediaFiles[file_src] then
                        table.insert(Op.app.mediaFiles[file_src].instances, { track = tr, fxIndex = fx })
                    else
                        addMediaFile(file_src, FILE_TYPES.RS5K, true)
                        Op.app.mediaFiles[file_src].instances = { { track = tr, fxIndex = fx } }
                    end
                    Op.app.mediaFiles[file_src].newFileSize = Op.app.mediaFiles[file_src].sourceFileSize
                end
            end
        end
    end

    local function getFilesFromFrozenTracks()
        Op.app.logger:logDebug('-- GetMediaFiles() -> getFilesFromFrozenTracks()', nil, 1)
        local root = ReadRPP(Op.app.fullProjPath) -- Parse the RPP

        local tracks = root:findAllChunksByName("TRACK")
        for i, track in ipairs(tracks) do
            local freezes = track:findAllChunksByName("FREEZE")
            for j, freeze in ipairs(freezes) do
                local items = freeze:findAllChunksByName("ITEM")
                for k, item in ipairs(items) do
                    local sources = item:findAllChunksByName("SOURCE")
                    for s, source in ipairs(sources) do
                        local sourceType = source:getParam(1):getString()
                        if ALL_FORMATS[sourceType] == nil then break end
                        if ALL_FORMATS[sourceType].type == 'INCOMPATIBLE' then break end
                        local fileNodes = source:findAllNodesByName("FILE")
                        assert(fileNodes ~= nil, 'Frozen file not found')
                        local filename = fileNodes[1]:getParam(1):getString()
                        -- filename = filename -- convert path to relative if possible, to match the mediaFiles table
                        Op.app.logger:logDebug('Found frozen file', filename)
                        Op.app.mediaFiles[filename] = nil
                        addMediaFile(filename, FILE_TYPES.AUDIO, true)
                        Op.app.mediaFiles[filename].newFileSize = Op.app.mediaFiles[filename].sourceFileSize
                        Op.app.mediaFiles[filename].status_info = 'Used in a frozen track'
                    end
                end
            end
        end
    end


    -- * init
    Op.app.mediaFiles = {}
    Op.app.usedFiles = {} --keeps track of ALL files used in the session for cleaning the media folder
    local numMediaItems = r.CountMediaItems(0)
    Op.app.perform.pos = 0
    Op.app.perform.total = numMediaItems
    Op.app.mediaFileCount = 0

    getFilesFromItems(numMediaItems)
    getFilesFromRS5K()
    if settings.freezeHandling == FREEZE_HANDLING.KEEP then
        getFilesFromFrozenTracks()
    end
end

function CollectMedia()
    Op.app.logger:logInfo('-- CollectMedia()', nil)
    -- determine which files should be collected:
    local function shouldCollect(fileInfo)
        Op.app.logger:logDebug('-- CollectMedia() -> shouldCollect()', fileInfo.filenameWithPath, 1)
        if fileInfo.missing then return false end
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
        Op.app.logger:logDebug('-- CollectMedia() -> collectFile()', nil, 1)
        local targetPath = (Op.app.projPath .. fileInfo.collectBackupTargetPath .. OD_FolderSep()):gsub('//$', '/')
        local targetFileName = targetPath ..
            fileInfo.basename .. (fileInfo.ext and ('.' .. fileInfo.ext) or '')

        local uniqueFilename = OD_GenerateUniqueFilename(targetFileName)
        if not OD_FolderExists(targetPath) then
            Op.app.restore.foldersToDelete = Op.app.restore.foldersToDelete or {}
            table.insert(Op.app.restore.foldersToDelete, targetPath)
        end
        r.RecursiveCreateDirectory(targetPath, 0)
        local success = settings.collectOperation == COLLECT_OPERATION.COPY and
            OD_CopyFile(fileInfo.filenameWithPath, uniqueFilename, Op.app.logger) or
            OD_MoveFile(fileInfo.filenameWithPath, uniqueFilename, Op.app.logger)

        return success, uniqueFilename
    end

    local function applyToOriginal(filename, newFilename)
        Op.app.logger:logDebug('-- CollectMedia() -> applyToOriginal()',
            tostring(filename) .. ' -> ' .. tostring(newFilename), 1)
        local fileInfo = Op.app.mediaFiles[filename]
        Op.app.usedFiles[filename] = nil
        Op.app.usedFiles[newFilename] = 1
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
            local instanceCount = 0
            for i, instance in ipairs(fileInfo.instances) do
                instanceCount = instanceCount + 1
                r.TrackFX_SetNamedConfigParm(instance.track, instance.fxIndex, 'FILE0',
                    uniqueFilenameInBackupDestination or newFilename)
            end
            Op.app.logger:logDebug(
                ('Absolute target file reference set for %s instances of a RS5K sample'):format(instanceCount),
                uniqueFilenameInBackupDestination or newFilename)
        else
            local newSrc = r.PCM_Source_CreateFromFile(newFilename)
            if not settings.backup then
                Op.app.peakOperations[newFilename] = newSrc
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

    Op.app.perform.total = 0
    Op.app.perform.pos = 0
    -- determine_total
    for filename, fileInfo in pairs(Op.app.mediaFiles) do
        fileInfo.shouldCollect = shouldCollect(fileInfo)
        if fileInfo.shouldCollect then
            Op.app.perform.total = Op.app.perform.total + 1
        end
    end
    Op.app.logger:logInfo(tostring(Op.app.perform.total) .. ' files to collect', nil)
    coroutine.yield('Collecting Files')
    for filename, fileInfo in OD_PairsByOrder(Op.app.mediaFiles) do
        if fileInfo.shouldCollect then
            Op.app.perform.pos = Op.app.perform.pos + 1
            fileInfo.status = STATUS.COLLECTING
            -- if (Op.app.perform.pos - 1) % YIELD_FREQUENCY == 0 then
            Op.app.scroll = filename
            coroutine.yield('Collecting Files')
            -- end

            -- if backing up, should later copy (not move) *internal* files to the backup (leaving originals untouched)
            -- otherwise, should first copy/move(according to setting) them to the current project folder, in order
            -- to get correct relative file references in the RPP, and set them to later MOVE to the backup destination
            -- so they won't be left in the original folder.
            if (settings.backup and not fileInfo.external) then
                Op.app.logger:logInfo('Internal file - Set to copy', (fileInfo.filenameWithPath))
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
                fileInfo.status = STATUS.COLLECTED
            else
                -- the file's folder in the target folder should be according to the targetPath setting (or the recording path if targetPath is not set)
                fileInfo.collectBackupTargetPath = (settings.targetPaths[fileInfo.fileType] or Op.app.relProjectRecordingPath)
                    :gsub('\\', '/'):gsub('/$', ''):gsub('^/', '')
                if fileInfo.collectBackupTargetPath ~= '' then
                    fileInfo.collectBackupTargetPath = fileInfo
                        .collectBackupTargetPath .. OD_FolderSep()
                end
                local success, newFileName = collectFile(fileInfo)
                if success then
                    Op.app.logger:logInfo('Collected succesfully & Set to move',
                        (tostring(fileInfo.filenameWithPath) .. ' to ' .. tostring(newFileName)))
                    fileInfo.collectBackupOperation = COLLECT_BACKUP_OPERATION.MOVE
                    applyToOriginal(filename, newFileName)
                    fileInfo.status = STATUS.COLLECTED
                else
                    Op.app.logger:logError('Collection failed',
                        (tostring(fileInfo.filenameWithPath) .. ' to ' .. tostring(newFileName)))
                    fileInfo.status = STATUS.ERROR
                    fileInfo.status_info = 'collection failed'
                end
            end
        end
    end
end

-- Create new items to reflect the new occurrences
function MinimizeAndApplyMedia()
    Op.app.logger:logInfo('-- MinimizeAndApplyMedia()', nil)
    local function createTrackForFilename(filename)
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> createTrackForFilename()', filename, 1)
        local trackIndex = r.GetNumTracks()
        r.InsertTrackAtIndex(trackIndex, false)
        local track = r.GetTrack(0, trackIndex)
        local basename = filename:match("^.+[\\/](.+)$")
        local no_ext = basename:match("(.+)%.")
        Op.app.mediaFiles[filename].trackName = no_ext .. settings.suffix
        r.GetSetMediaTrackInfo_String(track, "P_NAME", Op.app.mediaFiles[filename].trackName, true)
        return track
    end

    local function addItemsToTrackAndWrapAround(track, fileInfo)
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> addItemsToTrackAndWrapAround()', nil, 1)
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
            r.SetMediaItemPosition(oc.newItem, OD_Round(oc.startTime - oc.startpadding,9), false)
            r.SetMediaItemLength(oc.newItem, OD_Round(ocLength,9), false)
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
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> removeSpaces()', nil, 1)
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
                    from = timeSelStart / Op.app.mediaFiles[filename].srclen,
                    to = timeSelEnd / Op.app.mediaFiles[filename].srclen,
                    order = counter
                })
                keepCounter = keepCounter +
                    ((timeSelEnd / Op.app.mediaFiles[filename].srclen) -
                        (timeSelStart / Op.app.mediaFiles[filename].srclen))
                counter = counter + 1
            end

            if currentPos < item.startTime + item.length then
                currentPos = item.startTime + item.length
            end
        end
        -- add last section
        if currentPos < Op.app.mediaFiles[filename].srclen then
            table.insert(sections, {
                from = currentPos / Op.app.mediaFiles[filename].srclen,
                to = 1,
                order = counter
            })
            keepCounter = keepCounter + (1 - currentPos / Op.app.mediaFiles[filename].srclen)
        end
        r.SelectAllMediaItems(0, false)
        r.Main_OnCommand(40310, 0) -- set ripple editing per track
        for i, item in ipairs(emptyItems) do
            r.SetMediaItemSelected(item, true)
            r.Main_OnCommand(40006, 0) -- delete item
        end
        r.Main_OnCommand(41990, 0)     -- toggle ripple editing
        Op.app.mediaFiles[filename].keep_length = 1 - keepCounter
        Op.app.mediaFiles[filename].sections = sections
    end

    local function saveNewPositions(fileInfo)
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> saveNewPositions()', nil, 1)
        for i, oc in ipairs(fileInfo.occurrences) do
            oc.newItemPosition = r.GetMediaItemInfo_Value(oc.newItem, "D_POSITION") + oc.startpadding
        end
    end

    local function trimItems(fileInfo, splitItems)
        -- Heavily lifted and then (slightly) adapted from "amagalma_Remove visible content (trim) behind items.lua"
        -- There's a similar native action (ID 40930) but it started bugging out at some point
        local function doTrimItems()
            local selItems = {}
            local selItemGUID = {}
            local toDelete = {}

            local function storeSelectedItems()
                local sel_item_cnt = r.CountSelectedMediaItems(0)
                if sel_item_cnt > 0 then
                    -- Store selected items
                    for i = 0, sel_item_cnt - 1 do
                        local selitem = r.GetSelectedMediaItem(0, i)
                        selItems[#selItems + 1] = selitem
                        local GUID = r.BR_GetMediaItemGUID(selitem)
                        selItemGUID[GUID] = true
                    end
                end
            end

            storeSelectedItems()

            local trimstate = r.GetToggleCommandStateEx(0, 41117) -- get Options: Toggle trim behind items state
            if trimstate == 1 then
                r.Main_OnCommand(41121, 0)                        -- Options: Disable trim behind items when editing
            end
            -- Unselect selected items (Needed for ApplyNudge!!!)
            for i = 1, #selItems do
                r.SetMediaItemSelected(selItems[i], false)
            end
            -- iterate selected items
            for i = 1, #selItems do
                local startTime = reaper.GetMediaItemInfo_Value(selItems[i], "D_POSITION")
                local endTime = startTime + reaper.GetMediaItemInfo_Value(selItems[i], "D_LENGTH")
                local track = reaper.GetMediaItem_Track(selItems[i])
                local track_items_cnt = reaper.CountTrackMediaItems(track)
                for j = 0, track_items_cnt - 1 do
                    local itemInTrack = reaper.GetTrackMediaItem(track, j)
                    local iitStart = reaper.GetMediaItemInfo_Value(itemInTrack, "D_POSITION")
                    local iitEnd = iitStart + reaper.GetMediaItemInfo_Value(itemInTrack, "D_LENGTH")
                    local selectedIIT = selItemGUID[reaper.BR_GetMediaItemGUID(itemInTrack)] or false
                    local failed = false
                    -- do not compare item with itself, compare only with unselected items
                    if itemInTrack ~= selItems[i] and not selectedIIT then
                        ---- Cases: ----

                        if OD_Round(iitStart, 9) >= OD_Round(startTime, 9) and OD_Round(iitEnd, 9) <= OD_Round(endTime, 9) then -- checked item is contained
                            -- Store items in table for deletion after item iteration finishes
                            toDelete[#toDelete + 1] = { track = track, item = itemInTrack }
                        elseif OD_Round(iitStart, 9) >= OD_Round(startTime, 9) and OD_Round(iitStart, 9) < OD_Round(endTime, 9) and OD_Round(iitEnd, 9) > OD_Round(endTime, 9) then -- checked item touches item's End
                            reaper.SetMediaItemSelected(itemInTrack, true)
                            reaper.ApplyNudge(0, 1, 1, 1, OD_Round(endTime, 9), false, 0)
                            reaper.SetMediaItemSelected(itemInTrack, false)
                            -- remove fade in of trimmed item
                            reaper.SetMediaItemInfo_Value(itemInTrack, "D_FADEINLEN", 0)
                        elseif OD_Round(iitEnd, 9) > OD_Round(startTime, 9) and OD_Round(iitEnd, 9) <= OD_Round(endTime, 9) and OD_Round(iitStart, 9) < OD_Round(startTime, 9) then -- checked item touches item's Start
                            reaper.SetMediaItemSelected(itemInTrack, true)
                            reaper.ApplyNudge(0, 1, 3, 1, startTime, false, 0)
                            reaper.SetMediaItemSelected(itemInTrack, false)
                            -- remove fade out of trimmed item
                            reaper.SetMediaItemInfo_Value(itemInTrack, "D_FADEOUTLEN", 0)
                        elseif OD_Round(iitStart, 9) < OD_Round(startTime, 9) and OD_Round(iitEnd, 9) > OD_Round(endTime, 9) then -- checked item encloses selected item
                            local new_item = reaper.SplitMediaItem(itemInTrack, startTime)
                                -- raise('encloses selected item')
                                reaper.SetMediaItemSelected(new_item, true)
                                reaper.ApplyNudge(0, 1, 1, 1, endTime, false, 0)
                                reaper.SetMediaItemSelected(new_item, false)
                            -- checked item has nothing to do with selected item
                        else
                            -- do nothing
                        end
                        ----------------
                    end
                end
            end

            -- Delete items if needed --------------------------------
            if #toDelete > 0 then
                for i = 1, #toDelete do
                    reaper.DeleteTrackMediaItem(toDelete[i].track, toDelete[i].item)
                end
            end

            -- Re-select previously selected items -------------------
            for i = 1, #selItems do
                reaper.SetMediaItemSelected(selItems[i], true)
            end
            if trimstate == 1 then
                reaper.Main_OnCommand(41120, 0) -- Re-enable trim behind items (if it was enabled)
            end
        end

        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> trimItems()', nil, 1)
        -- then trim each object...
        for i, oc in ipairs(fileInfo.occurrences) do
            -- if item was deleted on the previous '40930' action, it is no longer valid
            if r.ValidatePtr2(0, oc.newItem, "MediaItem*") then
                r.SelectAllMediaItems(0, false)
                r.SetMediaItemInfo_Value(oc.newItem, "D_FADEINLEN", 0)
                r.SetMediaItemInfo_Value(oc.newItem, "D_FADEOUTLEN", 0)
                r.SetMediaItemSelected(oc.newItem, true)
                doTrimItems() -- replaces r.Main_OnCommand(40930, 0) (trim content behind) because it failed in some edge cases I couldn't really identify
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
                doTrimItems() -- replaces r.Main_OnCommand(40930, 0) (trim content behind) because it failed in some edge cases I couldn't really identify
            end
        end
    end

    local function glueItems(track)
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> glueItems()', nil, 1)
        -- temporarily remove max file size limitation, if it exists, otherwise glue operation will split every X time
        local maxrecsize_use = r.SNM_GetIntConfigVar('maxrecsize_use', 999)
        if maxrecsize_use == 999 then
            error('maxrecsize_use not found')
        end
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
            Op.app.logger:logError('Detected unsuccessful gluing (probably due to user cancelling)')
            error('cancelled by glue')
        end
        return r.GetTrackMediaItem(track, 0)
    end

    local function saveTakeStretchMarkers(oc)
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> saveTakeStretchMarkers()', nil, 1)
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
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> applyTakeStretchMarkers()', nil, 1)
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
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> applyTakeMarkers()', nil, 1)
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
        Op.app.logger:logDebug('-- MinimizeAndApplyMedia() -> applyGluedSourceToOriginal()', nil, 1)
        local fileInfo = Op.app.mediaFiles[originalFilename]
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
            local success = OD_MoveFile(sourceFilename, uniqueName, Op.app.logger)
            r.Main_OnCommand(40439, 0) -- online
            if not success then
                fileInfo.status = STATUS.ERROR
                fileInfo.status_info = 'move minimized version failed'
            else
                -- Update the glued item with the new source file and rebuild peaks

                newSrc = r.PCM_Source_CreateFromFile(uniqueName)
                fileInfo.newfilename = uniqueName
                -- update usedFiles table with the replaced file
                Op.app.usedFiles[originalFilename] = nil
                Op.app.usedFiles[uniqueName] = 1

                if not settings.backup then
                    Op.app.peakOperations[uniqueName] = newSrc
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
                    local rv, chunk = r.GetItemStateChunk(oc.item, '', false)
                    if rv and chunk:match('FREEZE .-%s.-%s(.-)\n') then 
                        chunk = chunk:gsub('(FREEZE .-%s.-%s).-(\n)','%1'..tostring(oc.newItemPosition)..'%2')
                        r.SetItemStateChunk(oc.item, chunk, false)
                    end
                    local _, oldTakeName = r.GetSetMediaItemTakeInfo_String(oc.take, 'P_NAME', '', false)
                    if oldTakeName:match(fileInfo.filenameWithoutPath) then
                        local _, newBasename, newExt = OD_DissectFilename(uniqueName)
                        if newBasename then
                            r.GetSetMediaItemTakeInfo_String(oc.take, 'P_NAME',
                                oldTakeName:gsub(fileInfo.filenameWithoutPath,
                                    newBasename .. (newExt and ('.' .. newExt) or '')), true)
                        end
                    end
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
    Op.app.perform.total = Op.app.mediaFileCount
    Op.app.perform.pos = 0
    coroutine.yield('Minimizing Files')
    for filename, fileInfo in OD_PairsByOrder(Op.app.mediaFiles) do
        if not fileInfo.ignore and not fileInfo.missing then
            Op.app.logger:logDebug('Processing file', filename)
            Op.app.scroll = filename
            fileInfo.status = STATUS.MINIMIZING
            Op.app.perform.pos = Op.app.perform.pos + 1
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
                Op.app.logger:logInfo('Nothing to minimize', filename)
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
                if fileInfo.status == STATUS.ERROR then
                    Op.app.logger:logError('Minimize error', (filename .. ' -> ' .. tostring(fileInfo.newfilename)))
                else
                    Op.app.logger:logInfo('Minimized Successfully',
                        (filename .. ' -> ' .. tostring(fileInfo.newfilename)))
                    fileInfo.status = STATUS.MINIMIZED
                end
            end
            r.DeleteTrack(track)

            -- coroutine.yield('Minimizing Files')
        else
            Op.app.logger:logInfo('Ignoring file', filename)
            Op.app.logger:logDebug('fileInfo.ignore', (fileInfo.ignore or false))
            Op.app.logger:logDebug('fileInfo.missing', (fileInfo.missing or false))
        end
    end
end

function FinalizePeaksBuild(count)
    Op.app.logger:logDebug('-- FinalizePeaksBuild()', count)
    local count = count or 0
    local total = 0
    for k, src in pairs(Op.app.peakOperations or {}) do
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
    Op.app.logger:logInfo('-- Restore()', nil)
    -- restore edit cursor position
    r.SetEditCurPos(Op.app.restore.pos, true, false)
    -- restore saved saving options
    r.SNM_SetIntConfigVar('saveopts', Op.app.restore.saveopts)
    -- restore saved "Save project file references with relative pathnames" setting
    r.SNM_SetIntConfigVar('projrelpath', Op.app.restore.projrelpath)
    -- restore quality
    r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", Op.app.restore.opencopy_cfgidx, true)
    r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", Op.app.restore.afxfrmt, true)
    r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", Op.app.restore.useprjsrate, true)
    -- delete temporary folders
    for i, folder in ipairs(Op.app.restore.foldersToDelete or {}) do
        local success, error = os.remove(folder)
        if success then
            Op.app.logger:logInfo('Temporary folder deleted', folder)
        else
            Op.app.logger:logError(('Temporary folder not deleted (%s)'):format(error), folder)
        end
    end
    -- delete temporary RPP backup file
    local success, error = os.remove(Op.app.revert.tmpBackupFileName)
    if success then
        Op.app.logger:logInfo('Temporary RPP backup file deleted', Op.app.revert.tmpBackupFileName)
    else
        Op.app.logger:logError(('Temporary RPP backup file not deleted (%s)'):format(error),
            Op.app.revert.tmpBackupFileName)
    end
end

function Revert(cancel)
    Op.app.logger:logInfo('-- Revert() cancel=', cancel or (false))
    -- restore temporary file saved before minimizing and open it
    local success = OD_CopyFile(Op.app.revert.tmpBackupFileName, Op.app.fullProjPath, Op.app.logger)
    if success then
        Op.app.logger:logInfo('Temporary RPP backup file restored', Op.app.revert.tmpBackupFileName)
    else
        Op.app.logger:logError('Temporary RPP backup file not restored', Op.app.revert.tmpBackupFileName)
    end
    -- delete files created but not used
    for filename, fileInfo in pairs(Op.app.mediaFiles) do
        if fileInfo.newfilename and fileInfo.status ~= STATUS.DONE then
            if OD_FileExists(fileInfo.newfilename) then
                r.reduce_open_files(2) 
                local success = os.remove(fileInfo.newfilename)
                if success then
                    Op.app.logger:logInfo('Temporary file deleted', fileInfo.newfilename)
                else
                    Op.app.logger:logError('Temporary file not deleted', fileInfo.newfilename)
                end
            end
        end
    end
    if cancel then
        r.Main_openProject("noprompt:" .. Op.app.fullProjPath)
        Op.app.mediaFiles = {}
        Op.app.usedFiles = {}
        Op.app.mediaFileCount = 0
        Restore() -- if not cancelled, restore will be called anyway
        Op.app.logger:logInfo('** Process Completed')
        Op.app.logger:flush()
    end
end

function Cancel(msg)
    -- r.ShowConsoleMsg(msg)
    Op.app.logger:logError('-- Cancel(msg)', msg)
    if msg then
        Op.app:msg(msg .. T.CANCEL_RELOAD, 'Operation Cancelled')
    end
    -- if Op.app.coPerform then coroutine.close(Op.app.coPerform) end
    Op.app.coPerform = nil
    Op.app.revertCancelOnNextFrame = true -- to allow for the message to appear before loading the project
end

function Prepare()
    Op.app.logger:logInfo('-- Prepare()', nil)
    local function setProjPaths()
        Op.app.logger:logDebug('-- Prepare() -> setProjPaths()', nil, 1)
        Op.app.projPath, Op.app.projFileName, Op.app.fullProjPath, Op.app.projectRecordingPath, Op.app.relProjectRecordingPath =
            OD_GetProjectPaths()
        Op.app.logger:logInfo('Op.app.projPath', Op.app.projPath)
        Op.app.logger:logInfo('Op.app.projFileName', Op.app.projFileName)
        Op.app.logger:logInfo('Op.app.fullProjPath', Op.app.fullProjPath)
        Op.app.logger:logInfo('Op.app.projectRecordingPath', Op.app.projectRecordingPath)
        Op.app.logger:logInfo('Op.app.relProjectRecordingPath', Op.app.relProjectRecordingPath)
    end
    local function prepareRestore()
        Op.app.logger:logDebug('-- Prepare() -> prepareRestore()', nil, 1)
        Op.app.logger:logDebug('Saving project and global settings')
        -- save current edit cursor position
        Op.app.restore.pos = r.GetCursorPosition()
        -- save current autosave options
        Op.app.restore.saveopts = r.SNM_GetIntConfigVar('saveopts', 999)
        if Op.app.restore.saveopts == 999 then
            error('saveopts not found')
        end
        Op.app.logger:logDebug('Op.app.restore.saveopts', Op.app.restore.saveopts)
        -- save current "Save project file references with relative pathnames" setting
        Op.app.restore.projrelpath = select(2, r.get_config_var_string('projrelpath'))
        Op.app.logger:logDebug('Op.app.restore.projrelpath', Op.app.restore.projrelpath)
        -- save current glue settings
        _, Op.app.restore.opencopy_cfgidx = r.GetSetProjectInfo_String(0, "OPENCOPY_CFGIDX", 0, false)
        Op.app.logger:logDebug('Op.app.restore.opencopy_cfgidx', Op.app.restore.opencopy_cfgidx)
        _, Op.app.restore.afxfrmt = r.GetSetProjectInfo_String(0, "APPLYFX_FORMAT", "", false)
        Op.app.logger:logDebug('Op.app.restore.afxfrmt', Op.app.restore.afxfrmt)
        Op.app.restore.useprjsrate = r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 0, false)
        Op.app.logger:logDebug('Op.app.restore.useprjsrate', Op.app.restore.useprjsrate)
    end
    local function prepareRevert()
        Op.app.logger:logDebug('-- Prepare() -> prepareRevert()', nil, 1)
        Op.app.revert.tmpBackupFileName = Op.app.projPath .. select(2, OD_DissectFilename(Op.app.projFileName)) .. '_' ..
            r.time_precise() .. '.RPP'
        local success = OD_CopyFile(Op.app.fullProjPath, Op.app.revert.tmpBackupFileName, Op.app.logger)
        if success then
            Op.app.logger:logInfo('Temporary RPP backup file created', Op.app.revert.tmpBackupFileName)
        else
            Op.app.logger:logError('Temporary RPP backup file not created', Op.app.revert.tmpBackupFileName)
        end
    end
    local function prepareSettings()
        Op.app.logger:logDebug('-- Prepare() -> prepareSettings()', nil, 1)
        local tmpOpts = Op.app.restore.saveopts

        -- disable autosave during operation
        if Op.app.restore.saveopts & 2 == 2 then
            tmpOpts = tmpOpts - 2
        end -- Save to project -> off
        if Op.app.restore.saveopts & 4 == 4 then
            tmpOpts = tmpOpts - 4
        end -- Save to timestamped file in project directory -> off
        if Op.app.restore.saveopts & 8 == 8 then
            tmpOpts = tmpOpts - 8
        end -- Save to timestamped file in additional directory -> off

        -- set disabled saving
        r.SNM_SetIntConfigVar('saveopts', tmpOpts)
        -- set "Save project file references with relative pathnames" enabled
        r.SNM_SetIntConfigVar('projrelpath', 1)
    end
    local function setQuality()
        Op.app.logger:logDebug('-- Prepare() -> setQuality()', nil, 1)
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
    Op.app.peakOperations = {}
end

function CreateBackupProject()
    Op.app.logger:logInfo('-- CreateBackupProject()', nil)
    r.Main_SaveProject(-1)
    local targetPath = (settings.backupDestination .. OD_FolderSep()):gsub('\\\\', '\\')
    Op.app.backupTargetProject = targetPath .. Op.app.projFileName
    OD_CopyFile(Op.app.fullProjPath, Op.app.backupTargetProject, Op.app.logger)
    Op.app.perform.total = Op.app.mediaFileCount
    Op.app.perform.pos = 0

    for filename, fileInfo in OD_PairsByOrder(Op.app.mediaFiles) do
        Op.app.scroll = filename
        -- move processed files
        r.RecursiveCreateDirectory(
            targetPath ..
            (fileInfo.collectBackupTargetPath or (fileInfo.pathIsRelative and fileInfo.relOrAbsPath or Op.app.relProjectRecordingPath)),
            0)
        Op.app.perform.pos = Op.app.perform.pos + 1
        if fileInfo.collectBackupOperation == COLLECT_BACKUP_OPERATION.MOVE or (settings.minimize and not fileInfo.ignore and not fileInfo.missing) then
            fileInfo.status = STATUS.MOVING
            coroutine.yield('Creating backup project')
            local _, newFN, newExt = OD_DissectFilename(fileInfo.newfilename)
            local target = (targetPath ..
                (fileInfo.collectBackupTargetPath or Op.app.relProjectRecordingPath) ..
                OD_FolderSep() .. newFN .. (newExt and ('.' .. newExt) or '')):gsub('\\\\', '\\')
            if OS_is.win then r.reduce_open_files(2) end -- windows won't delete/move files that are in use. not sure it's needed
            if OD_MoveFile(fileInfo.newfilename, target, Op.app.logger) then
                Op.app.logger:logInfo('File backup (Move) successful', (fileInfo.newfilename .. ' -> ' .. target))
                fileInfo.status = STATUS.DONE
            else
                Op.app.logger:logError('File backup (Move) failed',
                    (tostring(fileInfo.newfilename) .. ' -> ' .. tostring(target)))
                fileInfo.status = STATUS.ERROR
                fileInfo.status_info = 'move failed'
            end
        elseif not fileInfo.missing and (settings.minimize or fileInfo.collectBackupOperation == COLLECT_BACKUP_OPERATION.COPY or (not fileInfo.ignore)) then -- copy all other files, if in media folder
            if fileInfo.pathIsRelative then
                fileInfo.status = STATUS.COPYING
                coroutine.yield('Creating backup project')
                local target = (targetPath .. fileInfo.relOrAbsFile):gsub('\\\\', '\\')
                if OD_CopyFile(fileInfo.filenameWithPath, target, Op.app.logger) then
                    Op.app.logger:logInfo('File backup (Copy) successful',
                        (fileInfo.filenameWithPath .. ' -> ' .. target))
                    fileInfo.status = STATUS.DONE
                else
                    Op.app.logger:logError('File backup (Copy) failed',
                        (tostring(fileInfo.filenameWithPath) .. ' -> ' .. tostring(target)))
                    fileInfo.status = STATUS.ERROR
                    fileInfo.status_info = 'copy failed'
                end
            else
                Op.app.logger:logInfo('Not backing up. File path is absolute', (tostring(fileInfo.filenameWithPath)))
                fileInfo.status = STATUS.DONE
            end
        end
        coroutine.yield('Creating backup project')
    end
end

function NetworkedFilesExist()
    Op.app.logger:logDebug('-- NetworkedFilesExist()', nil)
    if OS_is.win then
        for filename, fileInfo in pairs(Op.app.mediaFiles) do
            if string.sub(fileInfo.filenameWithPath, 1, 2) == '\\\\' then
                return Op.app.logger:logError('Networked files exist', true)
            end
        end
    end
    return Op.app.logger:logDebug('No networked files exist', false)
end

function SubProjectsExist()
    Op.app.logger:logDebug('-- SubProjectsExist()', nil)
    for filename, fileInfo in pairs(Op.app.mediaFiles) do
        if fileInfo.fileType == FILE_TYPES.SUBPROJECT then
            return Op.app.logger:logError('Subprojects exist', true)
        end
    end
    return Op.app.logger:logDebug('No subprojects exist', false)
end

function DeleteOriginals()
    Op.app.logger:logInfo('-- DeleteOriginals()', nil)
    if settings.minimize and settings.deleteMethod ~= DELETE_METHOD.KEEP_IN_FOLDER then
        Op.app.perform.total = Op.app.mediaFileCount

        Op.app.perform.pos = 0
        local stat = settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and 'Moving originals to trash' or
            'Deleting originals'
        local filesToTrashWin = {}
        coroutine.yield(stat)
        for filename, fileInfo in OD_PairsByOrder(Op.app.mediaFiles) do
            -- delete original files which were replaced by minimized versions
            Op.app.perform.pos = Op.app.perform.pos + 1
            Op.app.scroll = filename
            if not fileInfo.external and not fileInfo.ignore and not fileInfo.missing then
                fileInfo.status = settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and STATUS.MOVING_TO_TRASH or
                    STATUS.DELETING
                coroutine.yield(stat)
                if OS_is.win then
                    if settings.deleteMethod ~= DELETE_METHOD.MOVE_TO_TRASH then
                        if OS_is.win then r.reduce_open_files(2) end -- windows won't delete/move files that are in use
                        if os.remove(fileInfo.filenameWithPath) then
                            Op.app.logger:logInfo('Delete successful', fileInfo.filenameWithPath)
                            Op.app.usedFiles[fileInfo.filenameWithPath] = nil
                            fileInfo.status = STATUS.DONE
                        else
                            Op.app.logger:logError('Delete failed', fileInfo.filenameWithPath)
                            fileInfo.status = STATUS.ERROR
                            fileInfo.error = 'delete original failed'
                        end
                    else -- if on windows but set to move to trash, we need to first collect filenames and only then send to trash to avoid opening powershell for each file
                        table.insert(filesToTrashWin, fileInfo.filenameWithPath)
                    end
                else
                    if settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH then
                        if OD_MoveToTrash(fileInfo.filenameWithPath, Op.app.logger) then
                            Op.app.logger:logInfo('Move to trash successful', fileInfo.filenameWithPath)
                            Op.app.usedFiles[fileInfo.filenameWithPath] = nil
                            fileInfo.status = STATUS.DONE
                        else
                            Op.app.logger:logError('Move to trash failed', fileInfo.filenameWithPath)
                            fileInfo.status = STATUS.ERROR
                            fileInfo.error = 'delete original failed'
                        end
                    elseif settings.deleteMethod == DELETE_METHOD.DELETE_FROM_DISK then
                        if os.remove(fileInfo.filenameWithPath) then
                            Op.app.logger:logInfo('Delete successful', fileInfo.filenameWithPath)
                            Op.app.usedFiles[fileInfo.filenameWithPath] = nil
                            fileInfo.status = STATUS.DONE
                        else
                            Op.app.logger:logError('Delete failed', fileInfo.filenameWithPath)
                            fileInfo.status = STATUS.ERROR
                            fileInfo.error = 'delete original failed'
                        end
                    elseif settings.deleteMethod == DELETE_METHOD.KEEP_IN_FOLDER then
                        Op.app.logger:logInfo('deleteMethod is set to "Keep In Folder". Leaving file intact.',
                            fileInfo.filenameWithPath)
                        fileInfo.status = STATUS.DONE
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
            r.reduce_open_files(2)                                -- windows won't delete/move files that are in use
            OD_MoveToTrash(filesToTrashWin, Op.app.logger)
            for filename, fileInfo in pairs(Op.app.mediaFiles) do -- verify which files were and were not removed
                if not OD_FileExists(fileInfo.filenameWithPath) then
                    Op.app.usedFiles[fileInfo.filenameWithPath] = nil
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
    Op.app.logger:logInfo('-- CleanMediaFolder()', nil)
    local function deleteUnusedFiles()
        Op.app.logger:logDebug('-- CleanMediaFolder() -> deleteUnusedFiles()', nil, 1)
        local stat = settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH and 'Moving unused files to trash' or
            'Deleting unused files'

        local filesToTrashWin = {}
        Op.app.perform.total = OD_TableLength(Op.app.ununsedFilesInRecordingFolder)
        Op.app.perform.pos = 0
        for i, file in ipairs(Op.app.ununsedFilesInRecordingFolder) do -- delete original files which were replaced by minimized versions
            Op.app.perform.pos = Op.app.perform.pos + 1
            if (Op.app.perform.pos - 1) % YIELD_FREQUENCY == 0 then
                coroutine.yield(stat)
            end
            if OS_is.win then
                if settings.deleteMethod ~= DELETE_METHOD.MOVE_TO_TRASH then
                    r.reduce_open_files(2) -- windows won't delete/move files that are in use
                    if os.remove(file.filename) then
                        Op.app.logger:logInfo('Delete successful', file.filename)
                        file.deleted = true
                    else
                        Op.app.logger:logError('Delete failed', file.filename)
                        file.deleted = false
                    end
                else -- if on windows but set to move to trash, we need to first collect filenames and only then send to trash to avoid opening powershell for each file
                    table.insert(filesToTrashWin, file.filename)
                end
            else
                if settings.deleteMethod == DELETE_METHOD.MOVE_TO_TRASH then
                    if OD_MoveToTrash(file.filename, Op.app.logger) then
                        Op.app.logger:logInfo('Move to trash successful', file.filename)
                        file.deleted = true
                    else
                        Op.app.logger:logError('Move to trash failed', file.filename)
                        file.deleted = false
                    end
                elseif settings.deleteMethod == DELETE_METHOD.DELETE_FROM_DISK then
                    if os.remove(file.filename) then
                        Op.app.logger:logInfo('Delete successful', file.filename)
                        file.deleted = true
                    else
                        Op.app.logger:logError('Move to trash failed', file.filename)
                        file.deleted = false
                    end
                end
            end
        end

        -- if on windows, trash all files at once to avoid powershelling for each file seperately
        if #filesToTrashWin > 0 then
            coroutine.yield(stat .. ' (might take some time...)')
            r.reduce_open_files(2)                                         -- windows won't delete/move files that are in use
            OD_MoveToTrash(filesToTrashWin, Op.app.logger)
            for i, file in ipairs(Op.app.ununsedFilesInRecordingFolder) do -- verify which files were and were not removed
                if not OD_FileExists(file.filename) then
                    Op.app.logger:logInfo('Move to trash successful', file.filename)
                    file.deleted = true
                else
                    Op.app.logger:logError('Move to trash failed', file.filename)
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
    Op.app.logger:logInfo('-- KeepActiveTakesOnly()', nil)
    -- Count the number of media items
    local itemCount = r.CountMediaItems(0)

    Op.app.perform.total = itemCount
    Op.app.perform.pos = 0
    -- Select all media items
    r.SelectAllMediaItems(0, true)

    -- Deselect the items where "Play all takes" is enabled
    for i = 0, itemCount - 1 do
        Op.app.perform.pos = Op.app.perform.pos + 1
        Op.app.perform.total = Op.app.perform.pos
        if (Op.app.perform.pos - 1) % YIELD_FREQUENCY == 0 then
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

function FixFrozenTracksFileAssociations()
    Op.app.logger:logInfo('-- GetMediaFiles() -> getFilesFromFrozenTracks()', nil, 1)

    local targetProj = settings.backup and Op.app.backupTargetProject or Op.app.fullProjPath

    r.Main_SaveProject(-1)

    local root = ReadRPP(targetProj) -- Parse the RPP

    local filenameUpdated = false
    local tracks = root:findAllChunksByName("TRACK")
    for i, track in ipairs(tracks) do
        local freezes = track:findAllChunksByName("FREEZE")
        for j, freeze in ipairs(freezes) do
            local items = freeze:findAllChunksByName("ITEM")
            for k, item in ipairs(items) do
                local sources = item:findAllChunksByName("SOURCE")
                for s, source in ipairs(sources) do
                    local sourceType = source:getParam(1):getString()
                    if ALL_FORMATS[sourceType] == nil then break end
                    if ALL_FORMATS[sourceType].type == 'INCOMPATIBLE' then break end
                    local filename = source:findAllNodesByName("FILE")[1]:getParam(1):getString()
                    -- filename = OD_GetRelativeOrAbsoluteFile(filename, Op.app.projPath) -- convert path to relative if possible, to match the mediaFiles table
                    local fileInfo = Op.app.mediaFiles[filename]
                    local newFilename = fileInfo.newfilename or filename

                    local _, unqBasename, unqExt = OD_DissectFilename(newFilename)
                    -- Frozen sources are saved as absolute paths,
                    -- so they need to be set to the backup target location
                    if settings.backup then
                        local targetPathInBackupDestination = (settings.backupDestination:gsub('\\', '/'):gsub('/$', '') .. OD_FolderSep() ..
                                (fileInfo.collectBackupTargetPath or (fileInfo.pathIsRelative and fileInfo.relOrAbsPath or Op.app.relProjectRecordingPath)) .. OD_FolderSep())
                            :gsub('//$', '/')
                        newFilename = targetPathInBackupDestination ..
                            unqBasename .. (unqExt and ('.' .. unqExt) or '')
                    end
                    newFilename = OS_is.win and newFilename:gsub('/', '\\') or newFilename
                    Op.app.logger:logDebug('Fixing frozen file association', filename .. ' -> ' .. newFilename)
                    source:findAllNodesByName("FILE")[1]:getParam(1):setString(newFilename)
                    if filename ~= newFilename then filenameUpdated = true end
                end
            end
        end
    end
    if filenameUpdated then
        Op.app.logger:logInfo('Filenames updated in freeze chunks')
        Op.app.logger:logDebug('Writing new RPP', targetProj)
        WriteRPP(targetProj, root)
        if not settings.backup then
            r.Main_openProject("noprompt:" .. Op.app.fullProjPath)
        end
    end
end

function UnlockFrozenItems()
    Op.app.logger:logInfo('-- GetMediaFiles() -> UnlockFrozenItems()', nil, 1)
    -- unlock all items in frozen tracks
    for i = 0, r.GetNumTracks(0) - 1 do
        local track = r.GetTrack(0, i)
        if r.BR_GetMediaTrackFreezeCount(track) > 0 then
            for j = 0, reaper.CountTrackMediaItems(track) - 1 do
                local item = reaper.GetTrackMediaItem(track, j)
                reaper.SetMediaItemInfo_Value(item, 'C_LOCK', 0)
                r.UpdateItemInProject(item)
            end
        end
    end
end

function RemoveFreezeChunks()
    Op.app.logger:logInfo('-- GetMediaFiles() -> RemoveFreezeChunks()', nil, 1)
    r.Main_SaveProject(-1)

    local targetProj = settings.backup and Op.app.backupTargetProject or Op.app.fullProjPath
    local root = ReadRPP(targetProj) -- Parse the RPP

    local freezeChunkRemoved = false
    local tracks = root:findAllChunksByName("TRACK")
    for i, track in ipairs(tracks) do
        local freezes = track:findAllChunksByName("FREEZE")
        for j, freeze in ipairs(freezes) do
            Op.app.logger:logDebug('Freeze chunk removed')
            freeze:remove()
            freezeChunkRemoved = true
        end
    end
    if freezeChunkRemoved then
        Op.app.logger:logInfo('Freeze chunks removed')
        Op.app.logger:logDebug('Writing new RPP', targetProj)
        WriteRPP(targetProj, root)
        if not settings.backup then
            r.Main_openProject("noprompt:" .. Op.app.fullProjPath)
        end
    end
end

function CalculateSavings()
    Op.app.logger:logDebug('-- CalculateSavings()', nil)
    Op.app.totalSpace = {}
    Op.app.totalSpace.deleted = 0
    Op.app.totalSpace.totalOriginalSize = 0
    Op.app.totalSpace.usedFilesSizeBeforeMinimization = 0
    Op.app.totalSpace.newSize = 0
    Op.app.totalSpace.notMoved = 0

    -- when backing up, media folder size isn't scanned, so it needs to be scanned now to calculate total size
    if settings.backup then getUnusedFilesInRecordingFolder() end
    for i, file in ipairs(Op.app.ununsedFilesInRecordingFolder or {}) do
        if file.deleted then Op.app.totalSpace.deleted = Op.app.totalSpace.deleted + file.size end
        if not Op.app.mediaFiles[file.filename] then
            Op.app.totalSpace.totalOriginalSize = Op.app.totalSpace.totalOriginalSize + file.size
        end
    end

    for filename, fileInfo in pairs(Op.app.mediaFiles) do
        Op.app.totalSpace.totalOriginalSize = Op.app.totalSpace.totalOriginalSize + fileInfo.sourceFileSize
        Op.app.totalSpace.usedFilesSizeBeforeMinimization = Op.app.totalSpace.usedFilesSizeBeforeMinimization +
            fileInfo.sourceFileSize
        Op.app.totalSpace.newSize = Op.app.totalSpace.newSize + fileInfo.newFileSize
    end


    Op.app.totalSpace.saved = Op.app.totalSpace.totalOriginalSize - Op.app.totalSpace.newSize
    Op.app.totalSpace.minimized = Op.app.totalSpace.usedFilesSizeBeforeMinimization - Op.app.totalSpace.newSize
    if settings.backup then Op.app.totalSpace.notMoved = Op.app.totalSpace.saved - Op.app.totalSpace.minimized end
    local msg =
        ('Original media folder size:      %s\n'):format(OD_GetFormattedFileSize(Op.app.totalSpace.totalOriginalSize)) ..
        (settings.minimize and
            ('Minimized files:                 %s\n'):format(OD_GetFormattedFileSize(Op.app.totalSpace.minimized) .. (Op.app.totalSpace.minimized < 0 and '*' or '')) or '') ..
        (settings.backup and
            ('Unused audio in original folder: %s\n'):format(OD_GetFormattedFileSize(Op.app.totalSpace.notMoved)) or '') ..
        ((settings.cleanMediaFolder and not settings.backup) and
            ('Deleted:                         %s\n'):format(OD_GetFormattedFileSize(Op.app.totalSpace.deleted)) or '') ..
        ('New size:                        %s\n'):format(OD_GetFormattedFileSize(Op.app.totalSpace.newSize)) ..
        '\n' ..
        ('Total savings:                   %s\n'):format(OD_GetFormattedFileSize(Op.app.totalSpace.saved)) ..
        ((Op.app.totalSpace.minimized < 0) and ('\n\n* Minimzed size is negative since\ncompressed files were glued together\nas raw PCM files.\n\nTo avoid that, you may select\n"%s" under\n"File types to minimize"'):format(MINIMIZE_SOURCE_TYPES_DESCRIPTIONS[MINIMIZE_SOURCE_TYPES.UNCOMPRESSED_AND_LOSSLESS]) or '')

    Op.app:msg(msg, 'Operation complete')
end
