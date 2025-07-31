-- @noindex
-- Marker Asset Type Module

MarkerAssetType = {}
MarkerAssetType.__index = MarkerAssetType
setmetatable(MarkerAssetType, BaseAssetType)

function MarkerAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Marker", "Markers")(class, context)
    -- Markers/Regions should be imported even if they can't be mapped to existing markers/regions
    instance.requiresMappingOnImport = false
    instance.updateOnProjectRefresh = true

    instance:addInteraction(0, 'go to %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            reaper.GoToMarker(0, asset.markerIdx, false)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift, 'select time between %asset and the next marker',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local mIdx = 0
            local nextMarkerPos = nil
            while true do
                local retval, isrgn, pos, regend, name, markrgnindexnumber = r.EnumProjectMarkers2(0, mIdx)
                if retval == 0 then
                    break
                end
                if pos > asset.pos then
                    if nextMarkerPos and pos < nextMarkerPos then
                        nextMarkerPos = pos
                    elseif not nextMarkerPos then
                        nextMarkerPos = pos
                    end
                end
                mIdx = mIdx + 1
            end
            r.GetSet_LoopTimeRange(true, true, asset.pos, nextMarkerPos or asset.pos, true)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift  | ImGui.Mod_Alt,
        'go to %asset and select time between it and the next marker',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local mIdx = 0
            local nextMarkerPos = nil
            while true do
                local retval, isrgn, pos, regend, name, markrgnindexnumber = r.EnumProjectMarkers2(0, mIdx)
                if retval == 0 then
                    break
                end
                if pos > asset.pos then
                    if nextMarkerPos and pos < nextMarkerPos then
                        nextMarkerPos = pos
                    elseif not nextMarkerPos then
                        nextMarkerPos = pos
                    end
                end
                mIdx = mIdx + 1
            end
            r.GetSet_LoopTimeRange(true, true, asset.pos, nextMarkerPos or asset.pos, true)
            reaper.GoToMarker(0, asset.markerIdx, false)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl,
        'select time between %asset and the next marker. Set to repeat',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local mIdx = 0
            local nextMarkerPos = nil
            while true do
                local retval, isrgn, pos, regend, name, markrgnindexnumber = r.EnumProjectMarkers2(0, mIdx)
                if retval == 0 then
                    break
                end
                if pos > asset.pos then
                    if nextMarkerPos and pos < nextMarkerPos then
                        nextMarkerPos = pos
                    elseif not nextMarkerPos then
                        nextMarkerPos = pos
                    end
                end
                mIdx = mIdx + 1
            end
            r.GetSet_LoopTimeRange(true, true, asset.pos, nextMarkerPos or asset.pos, true)
            reaper.GetSetRepeat(1)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl | ImGui.Mod_Alt,
        'go to %asset and select time between it and the next marker. Set to repeat',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            local mIdx = 0
            local nextMarkerPos = nil
            while true do
                local retval, isrgn, pos, regend, name, markrgnindexnumber = r.EnumProjectMarkers2(0, mIdx)
                if retval == 0 then
                    break
                end
                if pos > asset.pos then
                    if nextMarkerPos and pos < nextMarkerPos then
                        nextMarkerPos = pos
                    elseif not nextMarkerPos then
                        nextMarkerPos = pos
                    end
                end
                mIdx = mIdx + 1
            end
            r.GetSet_LoopTimeRange(true, true, asset.pos, nextMarkerPos or asset.pos, true)
            reaper.GetSetRepeat(1)
            reaper.GoToMarker(0, asset.markerIdx, false)
            return true
        end)

    return instance
end

function MarkerAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local mIdx = 0
    local found = false
    local numMarkers = 0
    local projectName = r.GetProjectName(0)
    while true do
        local retval, isrgn, pos, regend, name, markrgnindexnumber, color = r.EnumProjectMarkers3(0, mIdx)
        if retval == 0 then
            break
        end
        if not isrgn then
            numMarkers = numMarkers + 1
            local markerId = 'M' .. markrgnindexnumber

            -- Capture context from asset type scope
            local context = self.context

            local markerData = {
                engine = context.engine,
                order = mIdx,
                name = name,
                pos = pos,
                color = ImGui.ColorConvertNative(color) * 0x100 | 0xff,
                uuid = projectName .. markerId,
                markerId = markerId,
                markerIdx = markrgnindexnumber,
            }
            table.insert(data, markerData)
        end
        mIdx = mIdx + 1
    end
    return data
end

function MarkerAssetType:assembleAsset(marker)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = marker.uuid,
        searchText = { { text = marker.name }, { text = marker.markerId } },
        group = self.group,
    })

    asset.order = marker.order
    asset.pos = marker.pos
    asset.color = marker.color
    asset.markerIdx = marker.markerIdx
    return asset
end
