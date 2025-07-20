-- @noindex
-- Action Asset Type Module

ActionAssetType = {}
ActionAssetType.__index = ActionAssetType
setmetatable(ActionAssetType, BaseAssetType)

ActionAssetType.new = BaseAssetType:createStandardConstructor("Actions", ASSETS.ACTION, ACTIONS_GROUP)

function ActionAssetType:getData()
    self.context.logger:logDebug('-- ActionAssetType:getData()')
    self.data = {}
    
    -- Simplified action enumeration - would need proper REAPER API integration
    local placeholderActions = {
        { id = 40001, name = "Insert new track", prefix = "Main", order = 1 },
        { id = 40005, name = "Remove tracks", prefix = "Main", order = 2 },
    }
    
    for _, action in ipairs(placeholderActions) do
        action.shortcuts = {}
        table.insert(self.data, action)
    end
    
    self:logDataStats("actions", #self.data)
    return self.data
end

function ActionAssetType:getExecuteFunction()
    return function(self, context, contextData)
        r.Main_OnCommand(self.load, 0)
    end
end

function ActionAssetType:assembleAsset(action)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = action.id,
        searchText = { { text = action.name }, { text = action.prefix or '' } },
        group = self.group,
        order = action.order
    })
    asset.shortcuts = action.shortcuts
    return asset
end
