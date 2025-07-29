-- @noindex
-- Marker Asset Type Module

MarkerAssetType = {}
MarkerAssetType.__index = MarkerAssetType
setmetatable(MarkerAssetType, BaseAssetType)

function MarkerAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Marker/Region", "Markers/Regions")(class, context)
    -- Markers/Regions should be imported even if they can't be mapped to existing markers/regions
    instance.requiresMappingOnImport = false
    instance.updateOnProjectRefresh = true
    return instance
end

function MarkerAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local mIdx = 0
    local found = false
    local numMarkers = 0
    local projectName = r.GetProjectName(0)
    while true do
        local retval, isrgn, pos, regend, name, markrgnindexnumber = r.EnumProjectMarkers2(0, mIdx)
        if retval == 0 then
            break
        end
        numMarkers = numMarkers + 1
        local markerType = isrgn and 'Region' or 'Marker'
        local markerId = (isrgn and 'R' or 'M') .. markrgnindexnumber

        -- Capture context from asset type scope
        local context = self.context

        local markerData = {
            engine = context.engine,
            order = mIdx,
            name = name,
            pos = pos,
            isrgn = isrgn,
            regend = regend,
            uuid = projectName .. markerId,
            markerId = markerId,
            markerIdx = markrgnindexnumber,
            markerType = markerType
        }
        table.insert(data, markerData)
        mIdx = mIdx + 1
    end
    return data
end

function MarkerAssetType:getExecuteFunction()
    return function(self, mods, context, contextData)
        if OD_BfCheck(context, ImGui.Mod_Shift) and self.isrgn then
            r.GetSet_LoopTimeRange(true, OD_BfCheck(context, ImGui.Mod_Alt), self.pos, self.regend, true)
            if OD_BfCheck(context, ImGui.Mod_Alt) then
                reaper.GoToRegion(0, self.markerIdx, false)
            end
        else
            if self.isrgn then
                reaper.GoToRegion(0, self.markerIdx, false)
            else
                reaper.GoToMarker(0, self.markerIdx, false)
            end
        end
        return true
    end
end

function MarkerAssetType:assembleAsset(marker)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = marker.uuid,
        searchText = { { text = marker.name }, { text = marker.markerType }, { text = marker.markerId } },
        group = self.group,
    })

    asset.order = marker.order
    asset.isrgn = marker.isrgn
    asset.pos = marker.pos
    asset.regend = marker.regend
    asset.markerIdx = marker.markerIdx
    return asset
end
