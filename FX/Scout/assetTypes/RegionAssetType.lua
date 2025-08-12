-- @noindex
-- Region Asset Type Module

RegionAssetType = {}
RegionAssetType.__index = RegionAssetType
setmetatable(RegionAssetType, BaseAssetType)

function RegionAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Region", "Regions")(class, context)
    instance.allowMultiple = false

    -- Regions should be imported even if they can't be mapped to existing regions
    instance.requiresMappingOnImport = false
    instance.updateOnProjectRefresh = true
    instance.magicWord = 'R'

    instance:addInteraction(0, 'go to start of %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            reaper.GoToRegion(0, asset.regionIdx, false)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift, 'select time surrounded by %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            r.GetSet_LoopTimeRange(true, true, asset.pos, asset.regend, true)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Alt, 'select time surrounded by %asset, set to repeat and go to it',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            r.GetSet_LoopTimeRange(true, true, asset.pos, asset.regend, true)
            reaper.GetSetRepeat(1)
            reaper.GoToRegion(0, asset.regionIdx, false)
            return true
        end)


    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl, 'select time surrounded by %asset, set to repeat',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            r.GetSet_LoopTimeRange(true, true, asset.pos, asset.regend, true)
            reaper.GetSetRepeat(1)
            return true
        end)

    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl | ImGui.Mod_Alt,
    'select time surrounded by %asset, set to repeat and go to it',
        function(asset, mods, context, contextData, confirm, total, index, tempStore, skipAllConfirmations)
            r.GetSet_LoopTimeRange(true, true, asset.pos, asset.regend, true)
            reaper.GetSetRepeat(1)
            reaper.GoToRegion(0, asset.regionIdx, false)
            return true
        end)

    return instance
end

function RegionAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local mIdx = 0
    local found = false
    local numRegions = 0
    local projectName = r.GetProjectName(0)
    while true do
        local retval, isrgn, pos, regend, name, markrgnindexnumber, color = r.EnumProjectMarkers3(0, mIdx)
        if retval == 0 then
            break
        end
        if isrgn then
            numRegions = numRegions + 1
            local regionId = 'R' .. markrgnindexnumber

            -- Capture context from asset type scope
            local context = self.context

            local regionData = {
                engine = context.engine,
                order = mIdx,
                name = name,
                pos = pos,
                regend = regend,
                color = ImGui.ColorConvertNative(color) * 0x100 | 0xff,
                uuid = projectName .. regionId,
                regionId = regionId,
                regionIdx = markrgnindexnumber,
            }
            table.insert(data, regionData)
        end
        mIdx = mIdx + 1
    end
    return data
end

function RegionAssetType:assembleAsset(region)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = region.uuid,
        searchText = { { text = region.name }, { text = region.regionId } },
        group = self.group,
    })

    asset.order = region.order
    asset.pos = region.pos
    asset.color = region.color
    asset.regend = region.regend
    asset.regionIdx = region.regionIdx
    return asset
end
