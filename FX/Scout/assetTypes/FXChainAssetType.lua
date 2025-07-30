-- @noindex
-- FX Chain Asset Type Module

FXChainAssetType = {}
FXChainAssetType.__index = FXChainAssetType
setmetatable(FXChainAssetType, BaseAssetType)

local helpers = {}
function FXChainAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("FX Chain", "FX Chains")(class, context)
    -- FX Chains are file-based assets (.rfxchain files)
    instance.shouldMapBaseFilenames = true

    instance:addInteraction(0, 'add %asset to selected track(s) or create a new track if none is selected',
        function(asset, mods, context, contextData, confirm, total, index)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(asset.context.temp, context, contextData, confirm)

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
                    asset.context.temp.newTrack = r.GetTrack(0, numTracks)
                end
                local originalUIState = instance:setPluginUIState()
                local fxIndex = r.TrackFX_AddByName(asset.context.temp.newTrack, asset.load, false, -1)
                instance:resetPluginUIState(originalUIState)
                if index == total then asset.context.temp.newTrack = nil end
                return true, ('Added %d FX to a new track'):format(total)
            end
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_OBJECT'], 'add %asset to dragged %dragTargetObject',
        function(asset, mods, context, contextData, confirm, total, index)
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
        function(asset, mods, context, contextData, confirm, total, index)
            if index == 1 then
                local numTracks = r.CountTracks(0)
                r.InsertTrackAtIndex(numTracks, true)
                asset.context.temp.newTrack = r.GetTrack(0, numTracks)
            end
            local originalUIState = instance:setPluginUIState()
            local fxIndex = r.TrackFX_AddByName(asset.context.temp.newTrack, asset.load, false, -1)
            instance:resetPluginUIState(originalUIState)
            if index == total then asset.context.temp.newTrack = nil end
            return true, ('Added %d FX to a new track'):format(total)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK']| ImGui.Mod_Ctrl,
        'add %asset to %singular(a new track)%plural(%count new tracks (each on its own track))',
        function(asset, mods, context, contextData, confirm, total, index)
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
        function(asset, mods, context, contextData, confirm, total, index)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(asset.context.temp, context, contextData, confirm)

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
        function(asset, mods, context, contextData, confirm, total, index)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(asset.context.temp, context, contextData, confirm)
            if selectedTracks and #selectedTracks > 0 then
                if index == 1 then asset.context.temp.newSendTrack = helpers.createSendTrack(asset) end
                local originalUIState = instance:setPluginUIState()
                r.TrackFX_AddByName(asset.context.temp.newSendTrack, asset.load, false, -1)
                instance:resetPluginUIState(originalUIState)

                if index == 1 then
                    for _, track in ipairs(selectedTracks) do
                        if asset.context.temp.newSendTrack then
                            reaper.GetSetMediaTrackInfo_String(asset.context.temp.newSendTrack, "P_NAME",
                                asset.searchText[1].text .. (total > 1 and ' ( + ' .. total - 1 .. ' more)' or ''), true)
                            local rv = reaper.CreateTrackSend(track, asset.context.temp.newSendTrack)
                        end
                    end
                end
                if index == total then asset.context.temp.newSendTrack = nil end

                return true, ('Sent %d track(s) to a new track with %d FX'):format(#selectedTracks, total)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
            end
        end)



    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl,
        'send to %singular(a new track)%plural(%count new tracks) with %asset%plural( (each FX on a separate track%))',
        function(asset, mods, context, contextData, confirm, total, index)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(asset.context.temp, context, contextData, confirm)
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

function FXChainAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local basePath = reaper.GetResourcePath() .. "/FXChains/"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'rfxchain', true)
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local chainPath = path:gsub('\\', '/'):gsub('/$', '')
        self.context.logger:logDebug('Found FX chain', file)
        table.insert(data, {
            load = file,
            path = chainPath,
            file = baseFilename,
            ext = ext
        })
    end
    return data
end

function FXChainAssetType:assembleAsset(chain)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = chain.load,
        searchText = { { text = chain.file }, { text = chain.path }, { text = chain.ext, hide = true } },
        group = self.group,
    })

    return asset
end

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
