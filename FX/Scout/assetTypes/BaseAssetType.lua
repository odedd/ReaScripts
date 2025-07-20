-- @noindex
-- Base Asset Type Module

BaseAssetType = {}
BaseAssetType.__index = BaseAssetType

function BaseAssetType.new(class, params)
    -- Create instance from subclass with params table
    local instance = setmetatable({}, class)
    instance.context = params.context
    instance.name = params.name
    instance.assetTypeId = params.assetTypeId
    instance.group = params.group
    return instance
end

-- Override these methods in asset type modules:

function BaseAssetType:getData()
    -- Should return array of asset data
    error("BaseAssetType:getData() must be implemented by subclass")
end

function BaseAssetType:getDataWithLogging()
    -- Wrapper that provides standard logging around getData()
    local className = getmetatable(self).__index == self and "BaseAssetType" or nil
    if not className then
        for globalName, globalValue in pairs(_G) do
            if globalValue == getmetatable(self).__index and globalName:match("AssetType$") then
                className = globalName
                break
            end
        end
    end
    
    self.context.logger:logDebug('-- ' .. (className or "Unknown") .. ':getData()')
    local data = self:getData()
    local count = data and #data or 0
    -- Use group name (plural) for logging instead of singular name
    local itemType = (self.group or self.name or "items"):lower()
    self.context.logger:logInfo('Found ' .. count .. ' ' .. itemType)
    return data
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

function BaseAssetType:createStandardConstructor(name, group)
    return function(class, context)
        -- Automatically infer asset type ID from the class name
        local inferredAssetTypeId = nil
        -- Try to find the class name in the global namespace
        for globalName, globalValue in pairs(_G) do
            if globalValue == class and globalName:match("AssetType$") then
                inferredAssetTypeId = ASSET_TYPE[globalName]
                break
            end
        end
        
        -- Use the display name as the group if no explicit group is provided
        local inferredGroup = group or name
        
        local instance = BaseAssetType.new(class, {
            name = name,
            assetTypeId = inferredAssetTypeId,
            group = inferredGroup,
            context = context
        })
        
        -- Default: require mapping during import (can be overridden by subclasses)
        instance.requiresMappingOnImport = true
        
        return instance
    end
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
