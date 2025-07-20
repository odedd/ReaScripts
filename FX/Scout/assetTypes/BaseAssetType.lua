-- @noindex
-- Base Asset Type Module

BaseAssetType = {}
BaseAssetType.__index = BaseAssetType

function BaseAssetType.new(class, params)
    -- Handle different calling patterns:
    -- 1. BaseAssetType.new(BaseAssetType, context) - direct context
    -- 2. BaseAssetType.new(subclass, {...}) - from subclass with params table
    local instance
    
    if params and type(params) == "table" and params.context then
        -- Called from subclass with params table: BaseAssetType.new(self, {...})
        instance = setmetatable({}, class)
        instance.context = params.context
        instance.name = params.name
        instance.assetTypeId = params.assetTypeId
        instance.group = params.group
    else
        -- Called directly with context as parameter: BaseAssetType.new(BaseAssetType, context)
        instance = setmetatable({}, class)
        instance.context = params
    end
    
    return instance
end

-- Override these methods in asset type modules:

function BaseAssetType:getData()
    -- Should return array of asset data
    error("BaseAssetType:getData() must be implemented by subclass")
end

function BaseAssetType:assembleAsset(assetData)
    -- Should return asset table for insertion into assets array
    error("BaseAssetType:assembleAsset() must be implemented by subclass")
end

function BaseAssetType:getExecuteFunction()
    -- Should return the execute function for assets of this type
    error("BaseAssetType:getExecuteFunction() must be implemented by subclass")
end

-- Common helper methods:

function BaseAssetType:createStandardConstructor(name, assetTypeId, group)
    return function(class, context)
        -- Use the display name as the group if no explicit group is provided
        local inferredGroup = group or name
        
        local instance = BaseAssetType.new(class, {
            name = name,
            assetTypeId = assetTypeId,
            group = inferredGroup,
            context = context
        })
        instance.data = {} -- Standard data storage
        return instance
    end
end

function BaseAssetType:logDataStats(typeName, count)
    self.context.logger:logInfo('Found ' .. count .. ' ' .. typeName:lower())
end

function BaseAssetType:createAssetBase(params)
    return {
        id = tostring(params.type) .. ' ' .. tostring(params.load),
        type = params.type,
        load = params.load,
        searchText = params.searchText,
        group = params.group,
        order = params.order or 0,
        context = self.context,
        db = self.context.db,  -- Add db reference for backward compatibility
        addTag = self.context.assetActions.addTag,
        removeTag = self.context.assetActions.removeTag,
        execute = self:getExecuteFunction(),
        toggleFavorite = self.context.assetActions.toggleFavorite
    }
end

function BaseAssetType:getFilterMenuEntry()
    if not self.name then
        return {} -- Return empty table instead of erroring for now
    end
    
    return {
        [self.name] = {
            order = self.filterOrder,
            query = { type = self.assetTypeId }
        }
    }
end
