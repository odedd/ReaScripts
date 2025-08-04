-- @noindex
-- Take Marker Asset Type Module

TakeMarkerAssetType = {}
TakeMarkerAssetType.__index = TakeMarkerAssetType
setmetatable(TakeMarkerAssetType, BaseAssetType)

function TakeMarkerAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Take Marker", "Take Markers")(class, context)
    -- Markers/Regions should be imported even if they can't be mapped to existing markers/regions
    instance.requiresMappingOnImport = false
    instance.updateOnProjectRefresh = true
    instance.allowMultiple = false

    instance:addInteraction(0, 'go to %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            r.SetEditCurPos(asset.absPos, true, false)
            return true
        end)

    return instance
end

function TakeMarkerAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local numTracks = reaper.CountTracks(0)
    local totalOrder = 0
    for trackIdx = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, trackIdx)
        local numItems = reaper.CountTrackMediaItems(track)

        for itemIdx = 0, numItems - 1 do
            local item = reaper.GetTrackMediaItem(track, itemIdx)
            local numTakes = reaper.CountTakes(item)

            for takeIdx = 0, numTakes - 1 do
                local take = reaper.GetTake(item, takeIdx)
                local takeGuid = reaper.BR_GetMediaItemTakeGUID(take)
                local numTakeMarkers = reaper.GetNumTakeMarkers(take)

                for markerIdx = 0, numTakeMarkers - 1 do
                    local markerPos, markerName, markerColor = reaper.GetTakeMarker(take, markerIdx)
                    local takePos = r.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
                    local itemLength = r.GetMediaItemInfo_Value(item, 'D_LENGTH')
                    local itemPos = r.GetMediaItemInfo_Value(item, 'D_POSITION')
                    local absPos = markerPos - takePos + itemPos
                    local markerIsHidden = absPos < itemPos or absPos > itemPos + itemLength
                    if markerName and markerPos ~= -1 then
                        totalOrder = totalOrder + 1
                        self.context.logger:logDebug('Take Marker added', markerName)

                        -- Capture context from asset type scope
                        local context = self.context

                        local takeMarkerData = {
                            uuid = takeGuid .. markerIdx,
                            name = markerName,
                            absPos = absPos,
                            pos = markerPos,
                            hidden = markerIsHidden,
                            color = ImGui.ColorConvertNative(markerColor) * 0x100 | 0xff,
                            trackIdx = trackIdx,
                            itemIdx = itemIdx,
                            takeIdx = takeIdx,
                            track = track,
                            item = item,
                            take = take,
                            takeName = reaper.GetTakeName(take),
                            markerIdx = markerIdx,
                            order = totalOrder
                        }
                        table.insert(data, takeMarkerData)
                    end
                end
            end
        end
    end
    return data
end

function TakeMarkerAssetType:assembleAsset(takeMarker)
    if not self.context.settings.current.showInvisibleTakeMarkers then
        if takeMarker.hidden then return nil end
    end

    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = takeMarker.uuid,
        searchText = { { text = takeMarker.name }, { text = takeMarker.takeName } },
        group = self.group,
    })
    asset.order = takeMarker.order
    asset.absPos = takeMarker.absPos
    asset.color = takeMarker.color
    asset.markerIdx = takeMarker.markerIdx
    asset.item = takeMarker.item
    asset.take = takeMarker.take
    return asset
end
