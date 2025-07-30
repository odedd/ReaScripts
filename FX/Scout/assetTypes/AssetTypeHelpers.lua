local helpers = {}
helpers.createSendTrack = function(asset)
    local newTrack = nil
    local numTracks = r.CountTracks(0)
    if asset.context.settings.current.createSendsInsideFolder then
        local folderFound = false
        for i = 0, numTracks - 1 do
            local scannedTrack = r.GetTrack(0, i)
            local _, trackName = r.GetTrackName(scannedTrack)
            if trackName == asset.context.settings.current.sendFolderName then
                folderFound = true
                newTrack = OD_InsertTrackAtFolder(scannedTrack)
                break
            end
        end

        if not folderFound then
            r.InsertTrackAtIndex(numTracks, true)
            local folder = r.GetTrack(0, numTracks)
            r.GetSetMediaTrackInfo_String(folder, 'P_NAME', asset.context.settings.current
                .sendFolderName,
                true)
            newTrack = OD_InsertTrackAtFolder(folder)
        end
    else
        r.InsertTrackAtIndex(numTracks, true)
        newTrack = r.GetTrack(0, numTracks)
    end
    return newTrack
end
helpers.addPluginActions = function(instance)
    instance:addInteraction(0, 'add %asset to selected track(s) or create a new track if none is selected',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(tempStore, context, contextData, confirm)

            if selectedTracks and #selectedTracks > 0 then
                local originalUIState = instance:setPluginUIState()
                for _, track in ipairs(selectedTracks) do
                    local fxIndex = r.TrackFX_AddByName(track, asset.load, false, -1)
                end
                instance:resetPluginUIState(originalUIState)
                return true, ('Added %s to %d tracks'):format(asset.searchText[1].text, #selectedTracks)
            elseif selectedTracks and #selectedTracks == 0 then
                if index == 1 then
                    local numTracks = r.CountTracks(0)
                    r.InsertTrackAtIndex(numTracks, true)
                    tempStore.newTrack = r.GetTrack(0, numTracks)
                end
                local originalUIState = instance:setPluginUIState()
                local fxIndex = r.TrackFX_AddByName(tempStore.newTrack, asset.load, false, -1)
                instance:resetPluginUIState(originalUIState)
                return true, ('Added %d FX to a new track'):format(total)
            end
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_OBJECT'], 'add %asset to dragged %dragTargetObject',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local originalUIState = instance:setPluginUIState()
            if contextData and r.ValidatePtr(contextData, "MediaItem*") then
                local take = r.GetActiveTake(contextData)
                local fxIndex = r.TakeFX_AddByName(take, asset.load, 1)
            else -- if not item then track
                local fxIndex = r.TrackFX_AddByName(contextData, asset.load, false, -1)
            end
            instance:resetPluginUIState(originalUIState)
            return true, ('Added %d FX to a new track'):format(total)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK'],
        'add %asset to a new track%plural( (all on one track))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            if index == 1 then
                local numTracks = r.CountTracks(0)
                r.InsertTrackAtIndex(numTracks, true)
                tempStore.newTrack = r.GetTrack(0, numTracks)
            end
            local originalUIState = instance:setPluginUIState()
            local fxIndex = r.TrackFX_AddByName(tempStore.newTrack, asset.load, false, -1)
            instance:resetPluginUIState(originalUIState)
            return true, ('Added %d FX to a new track'):format(total)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK']| ImGui.Mod_Ctrl,
        'add %asset to %singular(a new track)%plural(%count new tracks (each on its own track))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local numTracks = r.CountTracks(0)
            r.InsertTrackAtIndex(numTracks, true)
            local newTrack = r.GetTrack(0, numTracks)
            local originalUIState = instance:setPluginUIState()
            local fxIndex = r.TrackFX_AddByName(newTrack, asset.load, false, -1)
            instance:resetPluginUIState(originalUIState)
            return true, ('Added %d FX to new track (each on its own track)'):format(total)
        end)
    instance:addInteraction(ImGui.Mod_Alt, 'add %asset to selected item(s)',
        function(asset, mods, context, contextData, confirm)
            local selectedItems = instance:getSelectedItemsWithConfirmation(context, contextData, confirm, total, index)

            if selectedItems and #selectedItems > 0 then
                local originalUIState = instance:setPluginUIState()
                for _, item in ipairs(selectedItems) do
                    local take = r.GetActiveTake(item)
                    if take then
                        r.TakeFX_AddByName(take, asset.load, 1)
                    end
                end
                instance:resetPluginUIState(originalUIState)
                return true, ('Added %s to %d items'):format(asset.searchText[1].text, #selectedItems)
            elseif selectedItems and #selectedItems == 0 then
                return false, 'No items selected'
            end
        end)
    instance:addInteraction(ImGui.Mod_Alt | ImGui.Mod_Ctrl, 'add %asset to selected track(s) as input FX',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(tempStore, context, contextData, confirm)

            if selectedTracks and #selectedTracks > 0 then
                local originalUIState = instance:setPluginUIState()
                for _, track in ipairs(selectedTracks) do
                    local fxIndex = r.TrackFX_AddByName(track, asset.load, true, -1)
                end
                instance:resetPluginUIState(originalUIState)
                return true, ('Added %s to %d tracks'):format(asset.searchText[1].text, #selectedTracks)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
            end
        end)

    instance:addInteraction(ImGui.Mod_Shift,
        'send to a new track with %asset%plural( (all on the same track%))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(tempStore, context, contextData, confirm)
            if selectedTracks and #selectedTracks > 0 then
                if index == 1 then tempStore.newSendTrack = helpers.createSendTrack(asset) end
                local originalUIState = instance:setPluginUIState()
                r.TrackFX_AddByName(tempStore.newSendTrack, asset.load, false, -1)
                instance:resetPluginUIState(originalUIState)

                if index == 1 then
                    for _, track in ipairs(selectedTracks) do
                        if tempStore.newSendTrack then
                            reaper.GetSetMediaTrackInfo_String(tempStore.newSendTrack, "P_NAME",
                                asset.searchText[1].text .. (total > 1 and ' ( + ' .. total - 1 .. ' more)' or ''), true)
                            local rv = reaper.CreateTrackSend(track, tempStore.newSendTrack)
                        end
                    end
                end

                return true, ('Sent %d track(s) to a new track with %d FX'):format(#selectedTracks, total)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
            end
        end)



    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl,
        'send to %singular(a new track)%plural(%count new tracks) with %asset%plural( (each FX on a separate track%))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(tempStore, context, contextData, confirm)
            if selectedTracks and #selectedTracks > 0 then
                local newTrack = helpers.createSendTrack(asset)
                local originalUIState = instance:setPluginUIState()
                if newTrack then
                    r.TrackFX_AddByName(newTrack, asset.load, false, -1)
                end
                instance:resetPluginUIState(originalUIState)

                for _, track in ipairs(selectedTracks) do
                    if newTrack then
                        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", asset.searchText[1].text, true)
                        local rv = reaper.CreateTrackSend(track, newTrack)
                    end
                end
                return true,
                    ('Sent %d track(s) to a new track with %s'):format(#selectedTracks, asset.searchText[1].text)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
            end
        end)

    return instance
end

return helpers