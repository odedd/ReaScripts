-- @noindex

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

helpers.setPluginUIState = function(settings)
    -- Sets up plugin UI state based on settings, returns original state
    if settings.showFxUI ~= nil and settings.showFxUI ~= SHOW_FX_UI.FOLLOW_PREFERENCE then
        local originalState = tonumber(select(2, r.get_config_var_string('fxfloat_focus')))
        r.SNM_SetIntConfigVar('fxfloat_focus',
            OD_BfSet(originalState, 4, settings.showFxUI == SHOW_FX_UI.OPEN))
        return originalState
    end
    return nil -- No change needed
end

helpers.resetPluginUIState = function(originalState)
    -- Restores the original plugin UI state
    if originalState ~= nil then
        r.SNM_SetIntConfigVar('fxfloat_focus', originalState)
    end
end

helpers.setAsAnInstrumentTrack = function(track, currentSettings)
    if currentSettings.addInstrumentsAsInstrumentTracks then
        r.SetMediaTrackInfo_Value(track, "I_RECINPUT", 6112) -- all MIDI inputs (6112)
        r.SetMediaTrackInfo_Value(track, "I_RECMON", 1)
        r.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
    end
end
helpers.addPluginActions = function(instance)
    instance:addInteraction(0, 'add %asset to selected track(s) or create a new track if none is selected',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context,
                contextData, confirm)

            if selectedTracks and #selectedTracks > 0 then
                local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
                for _, track in ipairs(selectedTracks) do
                    local fxIndex = r.TrackFX_AddByName(track, asset.load, false, -1)
                    if asset.instrument then
                        helpers.setAsAnInstrumentTrack(track, asset.context.settings.current)
                    end
                end
                helpers.resetPluginUIState(originalUIState)
                return true, ('Added %s to %d tracks'):format(asset.searchText[1].text, #selectedTracks)
            elseif selectedTracks and #selectedTracks == 0 then
                if index == 1 then
                    local numTracks = r.CountTracks(0)
                    r.InsertTrackAtIndex(numTracks, true)
                    tempStore.newTrack = r.GetTrack(0, numTracks)
                    if asset.instrument then tempStore.instrumentExists = true end
                end
                local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
                local fxIndex = r.TrackFX_AddByName(tempStore.newTrack, asset.load, false, -1)
                helpers.resetPluginUIState(originalUIState)
                if index == total then
                    if tempStore.instrumentExists then
                        helpers.setAsAnInstrumentTrack(tempStore.newTrack, asset.context.settings.current)
                    end
                end
                return true, ('Added %d FX to a new track'):format(total)
            end
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_OBJECT'], 'add %asset to dragged %dragTargetObject',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
            if contextData and r.ValidatePtr(contextData, "MediaItem*") then
                local take = r.GetActiveTake(contextData)
                local fxIndex = r.TakeFX_AddByName(take, asset.load, 1)
                if asset.instrument then helpers.setAsAnInstrumentTrack(tempStore.newTrack, asset.context.settings.current) end
            else -- if not item then track
                local fxIndex = r.TrackFX_AddByName(contextData, asset.load, false, -1)
            end
            helpers.resetPluginUIState(originalUIState)
            return true, ('Added %d FX to a new track'):format(total)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK'],
        'add %asset to a new track%plural( (all on one track))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            if index == 1 then
                local numTracks = r.CountTracks(0)
                r.InsertTrackAtIndex(numTracks, true)
                tempStore.newTrack = r.GetTrack(0, numTracks)
                if asset.instrument then tempStore.instrumentExists = true end
            end
            local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
            local fxIndex = r.TrackFX_AddByName(tempStore.newTrack, asset.load, false, -1)
            helpers.resetPluginUIState(originalUIState)
            if index == total then
                if tempStore.instrumentExists then
                    helpers.setAsAnInstrumentTrack(tempStore.newTrack, asset.context.settings.current)
                end
            end
            return true, ('Added %d FX to a new track'):format(total)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK']| ImGui.Mod_Ctrl,
        'add %asset to %singular(a new track)%plural(%count new tracks (each on its own track))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local numTracks = r.CountTracks(0)
            r.InsertTrackAtIndex(numTracks, true)
            local newTrack = r.GetTrack(0, numTracks)
            local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
            local fxIndex = r.TrackFX_AddByName(newTrack, asset.load, false, -1)
            helpers.resetPluginUIState(originalUIState)
            if asset.instrument then helpers.setAsAnInstrumentTrack(newTrack, asset.context.settings.current) end
            return true, ('Added %d FX to new track (each on its own track)'):format(total)
        end)
    instance:addInteraction(ImGui.Mod_Alt, 'add %asset to selected item(s)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedItems = helpers.getSelectedItemsWithConfirmation(tempStore, asset.context, context, contextData,
                confirm)

            if selectedItems and #selectedItems > 0 then
                local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
                for _, item in ipairs(selectedItems) do
                    local take = r.GetActiveTake(item)
                    if take then
                        r.TakeFX_AddByName(take, asset.load, 1)
                    end
                end
                helpers.resetPluginUIState(originalUIState)
                return true, ('Added %s to %d items'):format(asset.searchText[1].text, #selectedItems)
            elseif selectedItems and #selectedItems == 0 then
                return false, 'No items selected'
            end
        end)
    instance:addInteraction(ImGui.Mod_Alt | ImGui.Mod_Ctrl, 'add %asset to selected track(s) as input FX',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context,
                contextData, confirm)

            if selectedTracks and #selectedTracks > 0 then
                local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
                for _, track in ipairs(selectedTracks) do
                    local fxIndex = r.TrackFX_AddByName(track, asset.load, true, -1)
                end
                helpers.resetPluginUIState(originalUIState)
                return true, ('Added %s to %d tracks'):format(asset.searchText[1].text, #selectedTracks)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
            end
        end)

    instance:addInteraction(ImGui.Mod_Shift,
        'send to a new track with %asset%plural( (all on the same track%))',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context,
                contextData, confirm)
            if selectedTracks and #selectedTracks > 0 then
                if index == 1 then tempStore.newSendTrack = helpers.createSendTrack(asset) end
                local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
                r.TrackFX_AddByName(tempStore.newSendTrack, asset.load, false, -1)
                helpers.resetPluginUIState(originalUIState)

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
            local selectedTracks = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context,
                contextData, confirm)
            if selectedTracks and #selectedTracks > 0 then
                local newTrack = helpers.createSendTrack(asset)
                local originalUIState = helpers.setPluginUIState(asset.context.settings.current)
                if newTrack then
                    r.TrackFX_AddByName(newTrack, asset.load, false, -1)
                end
                helpers.resetPluginUIState(originalUIState)

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

helpers.getSelectedTracksWithConfirmation = function(tempStorage, assetContext, context, contextData, confirm)
    -- Similar logic for items if needed by other asset types
    if not tempStorage.executeFunctionSelectedTracks then
        tempStorage.executeFunctionSelectedTracks = {}
        local numSelectedTracks = r.CountSelectedTracks2(0, true)
        for i = 0, numSelectedTracks - 1 do
            local track = r.GetSelectedTrack2(0, i, true)
            table.insert(tempStorage.executeFunctionSelectedTracks, track)
        end
    end
    if #tempStorage.executeFunctionSelectedTracks >= assetContext.settings.current.numberOfMediaItemsThatRequireConfirmation and not (confirm and confirm.multipleTracks) then
        assetContext.temp.confirmMultipleTracks = {
            count = #tempStorage.executeFunctionSelectedTracks,
            resultContext = context,
            contextData = contextData,
            confirm = confirm
        }
        return false, ('%s tracks selected, waiting for confirmation'):format(#tempStorage.executeFunctionSelectedTracks)
    end
    return tempStorage.executeFunctionSelectedTracks -- Proceed
end

helpers.getSelectedItemsWithConfirmation = function(tempStorage, assetContext, context, contextData, confirm)
    -- Similar logic for items if needed by other asset types
    local numSelectedItems = r.CountSelectedMediaItems(0)
    local items = {}
    for i = 0, numSelectedItems - 1 do
        local item = r.GetSelectedMediaItem(0, i)
        table.insert(items, item)
    end

    if #items >= assetContext.settings.current.numberOfMediaItemsThatRequireConfirmation and not (confirm and confirm.multipleMediaItems) then
        assetContext.temp.confirmMultipleMediaItems = {
            count = #items,
            resultContext = context,
            contextData = contextData,
            confirm = confirm
        }
        return false, ('%s items selected, waiting for confirmation'):format(#items)
    end
    return items -- Proceed
end

return helpers
