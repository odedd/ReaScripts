-- @noindex


function OD_GetTrackFromGuid(project, guid)
    
    local numTracks = reaper.CountTracks(project)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(project, i)
        local trackGuid = reaper.GetTrackGUID(track)
        if trackGuid == guid then
            return track
        end
    end
    return nil
end

function OD_InsertTrackAtFolder(folderTrack)
    local folderDepthChange = 0
    local trackFound = false  -- found track, not necessary in a folder form
    local folderFound = false -- the track which was found is a folder
    local foundFolderTrack = nil -- the track object that was found, used to set the folder depth if it's not a folder
    local newTrackIndex = 0 -- the index of the new track to be inserted
    local numTracks = r.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = r.GetTrack(0, i)
        newTrackIndex = i
        if folderFound then
            local lastTrackFolderDepth = r.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')
            folderDepthChange = folderDepthChange + lastTrackFolderDepth
            if folderDepthChange < 0 then -- last track of folder
                r.SetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH', lastTrackFolderDepth - folderDepthChange)
                break
            end
        end

        if track == folderTrack then
            local _, trackName = r.GetTrackName(track)
            trackFound = true
            foundFolderTrack = track
            local depth = r.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')
            if depth == 1 then -- track is a folder
                folderFound = true
            else
                trackFound = true
                folderDepthChange = depth
                newTrackIndex = i
                break
            end
        end
    end
    if not trackFound then return end
    r.InsertTrackAtIndex(newTrackIndex + 1, true)
    if not folderFound then -- Track was not a folder, so turning it into one
        r.SetMediaTrackInfo_Value(foundFolderTrack, 'I_FOLDERDEPTH', 1)
        folderDepthChange = folderDepthChange - 1
    end
    local newTrack = r.GetTrack(0, newTrackIndex + 1)
    r.SetMediaTrackInfo_Value(newTrack, 'I_FOLDERDEPTH', folderDepthChange)
    return newTrack
end