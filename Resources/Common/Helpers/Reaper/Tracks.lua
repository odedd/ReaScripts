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