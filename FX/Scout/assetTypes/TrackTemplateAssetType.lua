-- @noindex
-- Track Template Asset Type Module

TrackTemplateAssetType = {}
TrackTemplateAssetType.__index = TrackTemplateAssetType
setmetatable(TrackTemplateAssetType, BaseAssetType)

local helpers = dofile(Scr.dir .. 'AssetTypes/AssetTypeHelpers.lua')
function TrackTemplateAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Track Template", "Track Templates")(class, context)
    -- Track Templates are file-based assets (.RTrackTemplate files)
    instance.shouldMapBaseFilenames = true
    instance.magicWord = 'L'

    instance:addInteraction(0, 'load %asset as %singular(a )new track%plural(s)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            r.Main_openProject(asset.load)
            return true, ('loaded track template %s'):format(asset.searchText[1].text)
        end)
    instance:addInteraction(RESULT_CONTEXT.DRAGGED_TO_BLANK, 'load %asset as %singular(a )new track%plural(s)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            r.Main_openProject(asset.load)
            return true, ('loaded track template %s'):format(asset.searchText[1].text)
        end)
    instance:addInteraction(ImGui.Mod_Shift,
        'send selected track(s) to %singular(a )new track%plural(s) with %singular(template \'%asset\')%plural(%asset)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            local selectedTracks, msg = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context, mods,
                contextData, confirm, total, index, skipAllConfirmations)
            if selectedTracks and #selectedTracks > 0 then
                local tempGuids = {}
                local dummyTrack, dummyTrackFolderDepth, depthDelta
                dummyTrack = helpers.createSendTrack(asset)
                r.SetOnlyTrackSelected(dummyTrack)
                r.Main_OnCommand(40913, 0)
                local numTracks = r.CountTracks(0)
                for i = 0, numTracks - 1 do
                    local scannedTrack = r.GetTrack(0, i)
                    local trackGuid = r.GetTrackGUID(scannedTrack)
                    table.insert(tempGuids, trackGuid)
                end
                r.Main_openProject(asset.load)

                if dummyTrack then
                    dummyTrackFolderDepth = r.GetMediaTrackInfo_Value(dummyTrack, 'I_FOLDERDEPTH')
                    r.SetMediaTrackInfo_Value(dummyTrack, 'I_FOLDERDEPTH', 0)
                end

                numTracks = r.CountTracks(0)
                if index == 1 then
                    tempStore.addedTracks = {}
                end
                local lastTrack = nil
                for i = 0, numTracks - 1 do
                    local scannedTrack = r.GetTrack(0, i)
                    local trackGuid = r.GetTrackGUID(scannedTrack)
                    if not OD_HasValue(tempGuids, trackGuid) then
                        table.insert(tempStore.addedTracks, scannedTrack)
                        if dummyTrack then
                            depthDelta = r.GetMediaTrackInfo_Value(scannedTrack, 'I_FOLDERDEPTH')
                            lastTrack = scannedTrack
                        end
                    end
                end

                if dummyTrack then
                    r.SetMediaTrackInfo_Value(lastTrack, 'I_FOLDERDEPTH', dummyTrackFolderDepth + depthDelta)
                    r.DeleteTrack(dummyTrack)
                end
                if index == total then
                    local originalSendVol = helpers.setDefaultSendVolume(asset.context.settings.current)

                    for i, track in ipairs(selectedTracks) do
                        if i == 1 then
                            r.SetOnlyTrackSelected(track)
                            r.Main_OnCommand(40913, 0)
                        else
                            r.SetTrackSelected(track, true)
                        end
                        for j, addedTrack in ipairs(tempStore.addedTracks) do
                            reaper.CreateTrackSend(track, addedTrack)
                        end
                    end
                    helpers.resetDefaultSendVolume(originalSendVol)
                end
                return true, ('sent to a new track with template %s'):format(asset.searchText[1].text)
            else
                return false, msg
            end
        end)

    instance:addInteraction(ImGui.Mod_Shift | RESULT_CONTEXT.DRAGGED_TO_BLANK,
        'send selected track(s) to %singular(a )new track%plural(s) with %singular(template \'%asset\')%plural(%asset)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            local selectedTracks, msg = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context, mods,
                contextData, confirm, total, index, skipAllConfirmations)
            if selectedTracks and #selectedTracks > 0 then
                local tempGuids = {}
                local dummyTrack, dummyTrackFolderDepth, depthDelta
                dummyTrack = helpers.createSendTrack(asset)
                r.SetOnlyTrackSelected(dummyTrack)
                r.Main_OnCommand(40913, 0)
                local numTracks = r.CountTracks(0)
                for i = 0, numTracks - 1 do
                    local scannedTrack = r.GetTrack(0, i)
                    local trackGuid = r.GetTrackGUID(scannedTrack)
                    table.insert(tempGuids, trackGuid)
                end
                r.Main_openProject(asset.load)

                if dummyTrack then
                    dummyTrackFolderDepth = r.GetMediaTrackInfo_Value(dummyTrack, 'I_FOLDERDEPTH')
                    r.SetMediaTrackInfo_Value(dummyTrack, 'I_FOLDERDEPTH', 0)
                end

                numTracks = r.CountTracks(0)
                if index == 1 then
                    tempStore.addedTracks = {}
                end
                local lastTrack = nil
                for i = 0, numTracks - 1 do
                    local scannedTrack = r.GetTrack(0, i)
                    local trackGuid = r.GetTrackGUID(scannedTrack)
                    if not OD_HasValue(tempGuids, trackGuid) then
                        table.insert(tempStore.addedTracks, scannedTrack)
                        if dummyTrack then
                            depthDelta = r.GetMediaTrackInfo_Value(scannedTrack, 'I_FOLDERDEPTH')
                            lastTrack = scannedTrack
                        end
                    end
                end

                if dummyTrack then
                    r.SetMediaTrackInfo_Value(lastTrack, 'I_FOLDERDEPTH', dummyTrackFolderDepth + depthDelta)
                    r.DeleteTrack(dummyTrack)
                end
                if index == total then
                    local originalSendVol = helpers.setDefaultSendVolume(asset.context.settings.current)

                    for i, track in ipairs(selectedTracks) do
                        if i == 1 then
                            r.SetOnlyTrackSelected(track)
                            r.Main_OnCommand(40913, 0)
                        else
                            r.SetTrackSelected(track, true)
                        end
                        for j, addedTrack in ipairs(tempStore.addedTracks) do
                            reaper.CreateTrackSend(track, addedTrack)
                        end
                    end
                    helpers.resetDefaultSendVolume(originalSendVol)
                end
                return true, ('sent to a new track with template %s'):format(asset.searchText[1].text)
            else
                return false, msg
            end
        end)
    return instance
end

function TrackTemplateAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local basePath = reaper.GetResourcePath() .. "/TrackTemplates"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'RTrackTemplate', true)
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local ttLoad, ttPath = basePath .. OD_FolderSep() .. file, path:gsub('\\', '/'):gsub('/$', '')
        self.context.logger:logDebug('Found track template', ttLoad)
        table.insert(data, {
            load = ttLoad,
            path = ttPath,
            file = baseFilename,
            ext = ext
        })
    end
    return data
end

function TrackTemplateAssetType:assembleAsset(tt)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = tt.load,
        searchText = { { text = tt.file }, { text = tt.path } },
        group = self.group,
    })

    return asset
end
