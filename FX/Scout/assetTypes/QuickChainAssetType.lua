-- @noindex
-- Quick Chain Asset Type Module

QuickChainAssetType = {}
QuickChainAssetType.__index = QuickChainAssetType
setmetatable(QuickChainAssetType, BaseAssetType)

function QuickChainAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Quick Chain", "Quick Chains")(class, context)
    
    -- Quick Chains do not require mapping on import (they are user-created)
    instance.requiresMappingOnImport = false
    instance.allowMultiple = false

    -- Add interaction using the new system
    instance:addInteraction(0, 'execute %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            -- For now, just log that the Quick Chain would be executed
            -- The actual execution logic will be implemented later
            asset.context.logger:logInfo('Quick Chain "' .. asset.searchText[1].text .. '" would be executed here')
            return true
        end)

    return instance
end

function QuickChainAssetType:getData()
    local data = {}
    
    -- Get Quick Chains from UserData
    local quickChains = self.context.userdata.current.quickChains or {}
    
    for id, quickChain in pairs(quickChains) do
        table.insert(data, {
            id = id,
            name = quickChain.name,
            word = quickChain.word,
            items = quickChain.items or {},
            itemCount = #(quickChain.items or {})
        })
    end
    
    return data
end

function QuickChainAssetType:assembleAsset(quickChainData)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = quickChainData.id,
        searchText = { 
            { text = quickChainData.name },
            { text = quickChainData.word or '' }
        },
        group = self.group,
    })
    
    -- Add Quick Chain specific properties
    asset.quickChainId = quickChainData.id
    asset.word = quickChainData.word
    asset.items = quickChainData.items
    asset.itemCount = quickChainData.itemCount
    
    return asset
end
