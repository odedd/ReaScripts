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

function BaseAssetType:executeAndAddToRecents()
    local assetType = self -- Capture the asset type instance
    return function(asset, ...)
        -- Get the execute function from the asset type
        local executeFunction = assetType:getExecuteFunction()
        if executeFunction then
            -- Execute first and check if successful
            local success, result, logMsg = pcall(executeFunction, asset, ...)
            
            if success and result == true then
                -- Only add to recents if execution was successful AND returned true
                if asset.addToRecents then
                    asset:addToRecents()
                end
                assetType.context.logger:logInfo(logMsg)
                if assetType.context.settings.current.closeAfterExport then
                    assetType.context.flow.close()
                end
                -- Return the actual result from the execute function
                return result
            elseif success then
                -- Execution didn't throw error but returned false - don't add to recents
                assetType.context.logger:logDebug('Execution returned false for asset: ' .. 
                    (asset.searchText and asset.searchText[1] and asset.searchText[1].text or 'Unknown') ..'.'.. (logMsg and (' Reason: '.. logMsg) or '')) 
                return result
            else
                -- Log the error and don't add to recents
                assetType.context.logger:logError('Execution failed for asset: ' .. 
                    (asset.searchText and asset.searchText[1] and asset.searchText[1].text or 'Unknown') .. 
                    ' - Error: ' .. tostring(result))
                return false
            end
        else
            assetType.context.logger:logError('No execute function available for asset type: ' ..
                (assetType.name or 'Unknown'))
            return false
        end
    end
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
        
        -- Default: not file-based (can be overridden by subclasses)
        instance.shouldMapBaseFilenames = false
        
        -- Default: do not refresh item on project refresh
        instance.updateOnProjectRefresh = false

        return instance
    end
end

BaseAssetType.assetActions = {
    toggleFavorite = function(self)
        local key = self.type .. ' ' .. self.load
        self.favorite = self.context.tags:toggleAssetFavorite(key)
        
        -- Use the unified special groups marking function to handle group reassignment
        self.engine:markSpecialGroups()
        self.engine:sortAssets()
        self.context.flow.filterResults(nil, nil, {self})  -- Use multi-target to maintain selection on this asset
        return self.favorite == true
    end,
    -- Batch toggle favorites for multiple assets (more efficient than calling toggleFavorite multiple times)
    batchToggleFavorites = function(self, assets, willFavorite)
        local favorites = self.context.tags.current.favorites
        local changed = false
        
        for _, asset in ipairs(assets) do
            local key = asset.type .. ' ' .. asset.load
            if willFavorite and not asset.favorite then
                table.insert(favorites, 1, key)
                asset.favorite = true
                changed = true
            elseif not willFavorite and asset.favorite then
                OD_RemoveValue(favorites, key)
                asset.favorite = false
                changed = true
            end
        end
        
        if changed then
            self.context.tags:save()
            -- Use the unified special groups marking function to handle group reassignment
            self.engine:markSpecialGroups()
            self.engine:sortAssets()
            -- Don't call filterResults here - let the caller handle it with target assets
        end
        
        return changed
    end,
    moveFavorite = function(self, targetPosition)
        local favorite = self.context.tags.current.favorites
        local key = self.type .. ' ' .. self.load

        -- Check if this asset is actually a favorite
        if not OD_HasValue(favorite, key) then
            self.context.logger:logError('Cannot move non-favorite asset: ' .. key)
            return false
        end

        -- Validate target position
        if targetPosition < 1 or targetPosition > #favorite then
            self.context.logger:logError('Invalid target position: ' ..
                targetPosition .. ' (must be between 1 and ' .. #favorite .. ')')
            return false
        end

        -- Find current position
        local currentPosition = nil
        for i, favoriteId in ipairs(favorite) do
            if favoriteId == key then
                currentPosition = i
                break
            end
        end

        if not currentPosition then
            self.context.logger:logError('Could not find current position for favorite: ' .. key)
            return false
        end

        -- If already at target position, nothing to do
        if currentPosition == targetPosition then
            return true
        end

        -- Remove from current position
        table.remove(favorite, currentPosition)

        -- Insert at target position
        table.insert(favorite, targetPosition, key)

        self.context.tags:save()
        self.engine:markSpecialGroups()
        self.engine:sortAssets()
        self.context.flow.filterResults(nil, nil, {self})  -- Use multi-target to maintain selection on this asset

        self.context.logger:logDebug('Moved favorite "' ..
            key .. '" from position ' .. currentPosition .. ' to position ' .. targetPosition)
        return true
    end,
    addToRecents = function(self)
        local key = self.type .. ' ' .. self.load
        self.context.tags:addAssetToRecents(key)
        
        -- Use the unified special groups marking function
        self.engine:markSpecialGroups()
        self.engine:sortAssets()
        self.context.flow.filterResults(nil, nil, {self})  -- Use multi-target to maintain selection on this asset
    end,
    addTag = function(self, tag, saveToDB)
        local save = (saveToDB == nil) and true or saveToDB
        
        if not OD_HasValue(self.tags, tag.id) then
            table.insert(self.tags, tag.id)
            self.context.tags:addTagToAsset(self.id, tag.id, save)
        end
    end,
    removeTag = function(self, tag, saveToDB)
        local save = (saveToDB == nil) and true or saveToDB
        
        if OD_HasValue(self.tags, tag.id) then
            OD_RemoveValue(self.tags, tag.id)
            self.context.tags:removeTagFromAsset(self.id, tag.id, save)
        end
    end
}

function BaseAssetType:createAssetBase(params)
    return {
        id = tostring(params.type) .. ' ' .. tostring(params.load),
        type = params.type,
        load = params.load,
        searchText = params.searchText,
        group = params.group,
        context = self.context,
        engine = self.context.engine, -- Add engine reference for backward compatibility
        addTag = self.assetActions.addTag,
        removeTag = self.assetActions.removeTag,
        execute = self:executeAndAddToRecents(),
        toggleFavorite = self.assetActions.toggleFavorite,
        batchToggleFavorites = self.assetActions.batchToggleFavorites,
        moveFavorite = self.assetActions.moveFavorite,
        addToRecents = self.assetActions.addToRecents
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
