-- @noindex
-- Track Asset Type Module

TrackAssetType = {}
TrackAssetType.__index = TrackAssetType
setmetatable(TrackAssetType, BaseAssetType)

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local helpers = dofile(p .. 'AssetTypeHelpers.lua')
function TrackAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Track", "Tracks")(class, context)
    -- Tracks should be imported even if they can't be mapped to existing tracks
    instance.requiresMappingOnImport = false
    instance.updateOnProjectRefresh = true

    instance:addInteraction(0, 'select and scroll to %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            -- local targetGuid = asset.load

            if index == 1 then
                r.PreventUIRefresh(1)
                r.SetOnlyTrackSelected(asset.object)
            else
                r.SetTrackSelected(asset.object, true)
            end
            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINMIXER', 1)
            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINTCP', 1)
            if index == total then
                r.PreventUIRefresh(-1)
                r.SetMixerScroll(asset.object)
                r.Main_OnCommand(40913, 0)
                r.TrackList_AdjustWindows(false)
                r.UpdateArrange()
            end
            return true, ('selected %d track(s)'):format(total)
        end)
    instance:addInteraction(ImGui.Mod_Ctrl, 'select and scroll to %asset (and %singular(its)%plural(their) children)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            -- local targetGuid = asset.load

            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINMIXER', 1)
            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINTCP', 1)

            if index == 1 then
                r.PreventUIRefresh(1)
                r.SetOnlyTrackSelected(asset.object)
            else
                r.SetTrackSelected(asset.object, true)
            end


            local childTracks = OD_GetChildTracks(asset.object)
            for _, childTrack in ipairs(childTracks) do
                r.SetTrackSelected(childTrack, true)
                r.SetMediaTrackInfo_Value(childTrack, 'B_SHOWINMIXER', 1)
                r.SetMediaTrackInfo_Value(childTrack, 'B_SHOWINTCP', 1)
            end
            if index == total then
                r.PreventUIRefresh(-1)
                r.SetMixerScroll(asset.object)
                r.Main_OnCommand(40913, 0)
                r.TrackList_AdjustWindows(false)
                r.UpdateArrange()
            end
            return true, ('selected %d track(s) and their children'):format(total)
        end)

    instance:addInteraction(ImGui.Mod_Alt, 'only make %asset visible',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            if index == 1 then
                r.PreventUIRefresh(1)
                local numTracks = r.CountTracks(0)
                for i = 0, numTracks - 1 do
                    local track = r.GetTrack(0, i)
                    if track ~= asset.object then
                        r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
                        r.SetMediaTrackInfo_Value(track, 'B_SHOWINTCP', 0)
                    end
                end
                r.SetOnlyTrackSelected(asset.object)
            end

            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINMIXER', 1)
            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINTCP', 1)
            if index == total then
                r.SetMixerScroll(asset.object)
                r.PreventUIRefresh(-1)
                r.Main_OnCommand(40913, 0)
                r.TrackList_AdjustWindows(false)
                r.UpdateArrange()
            end
            return true, ('made %d track(s) visible'):format(total)
        end)

    instance:addInteraction(ImGui.Mod_Alt | ImGui.Mod_Ctrl,
        'only make %asset (and %singular(its)%plural(their) children) visible',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            if index == 1 then
                r.PreventUIRefresh(1)
                local numTracks = r.CountTracks(0)
                for i = 0, numTracks - 1 do
                    local track = r.GetTrack(0, i)
                    r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
                    r.SetMediaTrackInfo_Value(track, 'B_SHOWINTCP', 0)
                end
                r.SetOnlyTrackSelected(asset.object)
            end

            -- Make the parent track visible
            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINMIXER', 1)
            r.SetMediaTrackInfo_Value(asset.object, 'B_SHOWINTCP', 1)

            -- Make all child tracks visible
            local childTracks = OD_GetChildTracks(asset.object)
            for _, childTrack in ipairs(childTracks) do
                r.SetMediaTrackInfo_Value(childTrack, 'B_SHOWINMIXER', 1)
                r.SetMediaTrackInfo_Value(childTrack, 'B_SHOWINTCP', 1)
            end

            if index == total then
                r.SetMixerScroll(asset.object)
                r.PreventUIRefresh(-1)
                r.Main_OnCommand(40913, 0)
                r.TrackList_AdjustWindows(false)
                r.UpdateArrange()
            end
            return true, ('made %d track(s) and their children visible'):format(total)
        end)

    instance:addInteraction(ImGui.Mod_Shift, 'send from selected track(s) to %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local selectedTracks = helpers.getSelectedTracksWithConfirmation(tempStore, asset.context, context, mods,
                contextData, confirm)
            if selectedTracks and #selectedTracks > 0 then
                for _, track in ipairs(selectedTracks) do
                    local rv = reaper.CreateTrackSend(track, asset.object)
                end
                return true, ('Sent %d track(s) to track %s'):format(#selectedTracks, asset.searchText[1].text)
            elseif selectedTracks and #selectedTracks == 0 then
                return false, 'No tracks selected'
            end
        end)
    return instance
end

function TrackAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local trackName = select(2, reaper.GetTrackName(track))
        local trackGuid = reaper.GetTrackGUID(track)
        local trackIsHidden = reaper.GetMediaTrackInfo_Value(track, 'B_SHOWINTCP') == 0
        self.context.logger:logDebug('Track added', trackName)

        -- Capture context from asset type scope
        local context = self.context

        local trackData = {
            object = track,
            engine = context.engine,
            guid = trackGuid,
            hidden = trackIsHidden,
            order = i,
            _refreshColor = function(self)
                local color = ImGui.ColorConvertNative(reaper.GetTrackColor(track)) * 0x100 | 0xff
                self.color = color
            end,
            _refreshName = function(self)
                self.name = select(2, reaper.GetTrackName(self.object))
            end
        }
        trackData:_refreshName()
        trackData:_refreshColor()
        table.insert(data, trackData)
    end
    return data
end

function TrackAssetType:assembleAsset(track)
    if not self.context.settings.current.showInvisibleTracks and track.hidden then return nil end

    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = track.guid,
        searchText = { { text = track.name } },
        group = self.group,
    })
    asset.hidden = track.hidden
    asset.order = track.order
    asset.object = track.object
    asset.color = track.color

    return asset
end
