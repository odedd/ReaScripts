-- @noindex
-- QuickChain Asset Type Module

QuickChainPresetAssetType = {}
QuickChainPresetAssetType.__index = QuickChainPresetAssetType
setmetatable(QuickChainPresetAssetType, BaseAssetType)

local p = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local helpers = dofile(p .. 'AssetTypeHelpers.lua')

helpers.performQuickChainPresetAction = function(asset, resultContext, mods, contextData)
    local qcp = asset.object
    local resolvedAssets = asset.context.engine:getAssetsByKeys(qcp.items)
    asset.context.flow.executeSelectedResults(resolvedAssets,
        resultContext | RESULT_CONTEXT.QUICK_CHAIN, mods, contextData)
    return true
end
function QuickChainPresetAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("QuickChain Preset", "QuickChain Presets")(class, context)

    -- QuickChains do not require mapping on import (they are user-created)
    instance.requiresMappingOnImport = false
    instance.allowMultiple = false

    -- Add interaction using the new system

    instance:addInteraction(ImGui.Mod_Ctrl, 'load %asset to active QuickChain',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            asset.context.flow.loadQuickChain(asset.object)
            return true
        end)

    instance:addInteraction(0, 'add %asset items to selected track(s) or create a new track if none is selected',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context, 0)
        end)

    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_OBJECT'], 'add %asset items to dragged %dragTargetObject',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context | RESULT_CONTEXT['DRAGGED_TO_OBJECT'],0,contextData)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK'],
        'add %asset items to a new track (all FX on one track)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context | RESULT_CONTEXT['DRAGGED_TO_BLANK'],0)
        end)
    instance:addInteraction(RESULT_CONTEXT['DRAGGED_TO_BLANK']| ImGui.Mod_Ctrl,
        'add %asset items to new tracks (each FX on its own track)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context | RESULT_CONTEXT['DRAGGED_TO_BLANK'], ImGui.Mod_Ctrl)
        end)
    instance:addInteraction(ImGui.Mod_Alt, 'add %asset items to selected media item(s)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context, ImGui.Mod_Alt)
        end)
    instance:addInteraction(ImGui.Mod_Alt | ImGui.Mod_Ctrl,
        'add %asset items to selected track(s) as input FX or create a new track if none is selected',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context, ImGui.Mod_Alt | ImGui.Mod_Ctrl)
        end)
    instance:addInteraction(ImGui.Mod_Shift,
        'send to a new track with %asset items (all FX on the same track)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context, ImGui.Mod_Shift)
        end)
    instance:addInteraction(ImGui.Mod_Shift | ImGui.Mod_Ctrl,
        'send to new tracks with %asset items (each FX on a separate track)',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            return helpers.performQuickChainPresetAction(asset, context, ImGui.Mod_Shift | ImGui.Mod_Ctrl)
        end)
    return instance
end

function QuickChainPresetAssetType:getData()
    local data = {}

    -- Get QuickChains from UserData
    local quickChainPresets = self.context.userdata.current.quickChainPresets or {}

    for id, quickChainPreset in pairs(quickChainPresets) do
        table.insert(data, {
            id = id,
            name = quickChainPreset.name,
            word = quickChainPreset.word,
            object = quickChainPreset,
            items = quickChainPreset.items or {},
            itemCount = #(quickChainPreset.items or {})
        })
    end

    return data
end

function QuickChainPresetAssetType:assembleAsset(quickChainPresetData)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = quickChainPresetData.id,
        searchText = {
            { text = quickChainPresetData.name },
            { text = quickChainPresetData.word or '' }
        },
        group = self.group,
    })

    -- Add QuickChain specific properties
    asset.quickChainId = quickChainPresetData.id
    asset.word = quickChainPresetData.word
    asset.items = quickChainPresetData.items
    asset.itemCount = quickChainPresetData.itemCount
    asset.object = quickChainPresetData.object
    return asset
end
