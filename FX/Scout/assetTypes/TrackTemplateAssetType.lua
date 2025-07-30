-- @noindex
-- Track Template Asset Type Module

TrackTemplateAssetType = {}
TrackTemplateAssetType.__index = TrackTemplateAssetType
setmetatable(TrackTemplateAssetType, BaseAssetType)
local helpers = {}
function TrackTemplateAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Track Template", "Track Templates")(class, context)
    -- Track Templates are file-based assets (.RTrackTemplate files)
    instance.shouldMapBaseFilenames = true

    instance:addInteraction(0, 'load %asset as %singular(a )new track%plural(s)',
        function(asset, mods, context, contextData, confirm, total, index)
            r.Main_openProject(asset.load)
            return true, ('loaded track template %s'):format(asset.searchText[1].text)
        end)
    instance:addInteraction(ImGui.Mod_Shift, 'send to %singular(a )new track%plural(s) with template \'%asset\'',
        function(asset, mods, context, contextData, confirm, total, index)
            local selectedTracks = instance:getSelectedTracksWithConfirmation(asset.context.temp, context, contextData, confirm)
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
                    asset.context.temp.addedTracks = {}
                end
                local lastTrack = nil
                for i = 0, numTracks - 1 do
                    local scannedTrack = r.GetTrack(0, i)
                    local trackGuid = r.GetTrackGUID(scannedTrack)
                    if not OD_HasValue(tempGuids, trackGuid) then
                        table.insert(asset.context.temp.addedTracks, scannedTrack)
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
                    for i, track in ipairs(selectedTracks) do
                        if i == 1 then
                            r.SetOnlyTrackSelected(track)
                            r.Main_OnCommand(40913, 0)
                        else
                            r.SetTrackSelected(track, true)
                        end
                        for j, addedTrack in ipairs(asset.context.temp.addedTracks) do
                            reaper.CreateTrackSend(track, addedTrack)
                        end
                    end
                    asset.context.temp.addedTracks = nil
                end
                return true, ('sent to a new track with template %s'):format(asset.searchText[1].text)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
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
        searchText = { { text = tt.file }, { text = tt.path }, { text = tt.ext, hide = true } },
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
