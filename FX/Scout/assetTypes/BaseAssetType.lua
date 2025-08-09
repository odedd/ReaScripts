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

function BaseAssetType:getDataWithLogging(forceRefresh)
    -- Wrapper that provides standard logging around getData() with caching support
    local className = getmetatable(self).__index == self and "BaseAssetType" or nil
    if not className then
        for globalName, globalValue in pairs(_G) do
            if globalValue == getmetatable(self).__index and globalName:match("AssetType$") then
                className = globalName
                break
            end
        end
    end

    -- Check if data is already cached and forceRefresh is not requested
    if not forceRefresh and self._cachedData and #self._cachedData > 0 then
        local count = #self._cachedData
        local itemType = (self.group or self.name or "items"):lower()
        self.context.logger:logDebug('-- ' .. (className or "Unknown") .. ':getData() using cached data')
        self.context.logger:logInfo('Found ' .. count .. ' ' .. itemType .. ' (cached)')
        return self._cachedData
    end

    self.context.logger:logDebug('-- ' .. (className or "Unknown") .. ':getData()' .. (forceRefresh and ' (forced refresh)' or ''))
    local data = self:getData()
    local count = data and #data or 0
    -- Use group name (plural) for logging instead of singular name
    local itemType = (self.group or self.name or "items"):lower()
    self.context.logger:logInfo('Found ' .. count .. ' ' .. itemType)
    
    -- Cache the data for future use
    self._cachedData = data
    return data
end

function BaseAssetType:clearCache()
    -- Clear cached data to force refresh on next call
    self._cachedData = nil
    -- Also clear legacy self.data cache if it exists (for PluginAssetType compatibility)
    if self.data then
        self.data = nil
    end
end

function BaseAssetType:assembleAsset(assetData)
    -- Should return asset table for insertion into assets array
    error("BaseAssetType:assembleAsset() must be implemented by subclass")
end

function BaseAssetType:determineCorrectContext(mods, context)
    local context = context or 0
    if OD_BfCheck(context, RESULT_CONTEXT.IGNORE_KEYS) then return 0 end
    context = OD_BfSet(context, RESULT_CONTEXT.QUICK_CHAIN, false) -- Remove QUICK_CHAIN flag for interaction hints
    local correctContext =
        self.interactionHints[mods | context] and (mods | context) or
        self.interactionHints[mods] and (mods) or
        self.interactionHints[context] and (context) or
        self.interactionHints[0] and (0)
    return correctContext
end

function BaseAssetType:getExecuteFunction(mods, context)
    local class = getmetatable(self)
    local executeFunction = nil

    -- Determine which execute function to use based on context (modifier keys)
    if class.executeFunctions and mods then
        local correctContext = class:determineCorrectContext(mods, context)
        executeFunction = class.executeFunctions[correctContext]
    end

    return executeFunction
end

function BaseAssetType:parseInteractionHintTemplate(template, count, targetObject, assetName, manyPlaceholder)
    local result = template

    -- Handle singular/plural functions with proper nesting support
    if count == 1 then
        -- Keep singular content, remove plural functions entirely
        result = result:gsub("%%singular%((.-)%)", function(content)
            -- Process escaped parentheses within the content
            return content:gsub("%%%((.-)%%%)", "(%1)")
        end)
        -- Remove plural functions completely
        result = result:gsub("%%plural%([^)]*%([^)]*%)[^)]*%)", "") -- nested parens
        result = result:gsub("%%plural%([^)]*%)", "")               -- simple case
    else
        -- Remove singular functions completely
        result = result:gsub("%%singular%([^)]*%)", "")
        -- Keep plural content, process escaped parentheses
        result = result:gsub("%%plural%((.-)%)", function(content)
            -- Handle both paired and single escaped parentheses
            content = content:gsub("%%%((.-)%%%)", "(%1)") -- paired escapes
            content = content:gsub("%%%)", ")")            -- single closing escape
            content = content:gsub("%%%(", "(")            -- single opening escape
            return content
        end)
    end

    local manyPlaceholder = manyPlaceholder or 'results'
    local countText = count == -1 and '&&&' or tostring(count)
    -- Replace variables (escape % characters in replacement strings)
    local assetReplacement = count == 1 and assetName or (countText .. ' ' .. manyPlaceholder)
    result = result:gsub("%%asset", (assetReplacement:gsub("%%", "%%%%")))
    result = result:gsub("%%count", (countText:gsub("%%", "%%%%")))
    if targetObject and r.ValidatePtr(targetObject, "MediaItem*") then
        result = result:gsub("%%dragTargetObject", "item")
    elseif targetObject and r.ValidatePtr(targetObject, "Track*") then
        result = result:gsub("%%dragTargetObject", "track")
    else
        result = result:gsub("%%dragTargetObject", "track/item")
    end
    if count == -1 then result = result:gsub("&&& ", '') end

    -- Clean up any remaining escaped parentheses
    result = result:gsub("%%%((.-)%%%)", "(%1)") -- paired escapes
    result = result:gsub("%%%)", ")")            -- single closing escape
    result = result:gsub("%%%(", "(")            -- single opening escape

    return result
end

function BaseAssetType:getInteractionHintFor(mods, context, contextData, count)
    local class = self.class
    local count = count or 1
    local interactionHint = nil
    local correctContext = class:determineCorrectContext(mods, context)
    interactionHint = class.interactionHints[correctContext].text
    local quickChain = OD_BfCheck(context, RESULT_CONTEXT.QUICK_CHAIN)
    local assetName = quickChain and 'QuickChain' or self.searchText[1].text
    local pluralName = quickChain and 'QuickChain items' or (self.pluralName):lower()
    return class:parseInteractionHintTemplate(interactionHint, count, contextData, assetName,
        pluralName), correctContext | context
end

function BaseAssetType:executeAndAddToRecents()
    return function(asset, mods, context, contextData, confirm, total, index, tempStore)
        local assetType = self -- Capture the asset type instance

        local executeFunction = assetType:getExecuteFunction(mods, context)
        if executeFunction then
            -- some actions change track selection, so selected tracks need to be stored only once, before the first action.
            -- since this information (index, total) is only available here, executeFunctionSelectedTracks is nulled here
            -- so that getSelectedTracksWithConfirmation can set it once
            -- tempStore = tempStore or asset.context.temp.executeFunctionTempStore
            if index == 1 then asset.context.temp.executeFunctionTempStore = {} end
            -- Execute first and check if successful
            local success, result, logMsg
            if index == 1 or (assetType.allowMultiple and index > 1) then
                success, result, logMsg = pcall(executeFunction, asset, mods, context, contextData, confirm, total,
                    index, asset.context.temp.executeFunctionTempStore)
            else
                success = true
                result = false
                logMsg = 'Asset does not accept multiple selections - executed first asset only.'
            end
            logMsg = logMsg or ''

            if index == total then asset.context.temp.executeFunctionTempStore = {} end

            if success and result == true then
                -- Only add to recents if execution was successful AND returned true
                if asset.addToRecents and not OD_BfCheck(context, RESULT_CONTEXT.QUICK_CHAIN) then
                    asset:addToRecents(index == total)
                end
                assetType.context.logger:logInfo(logMsg)
                if assetType.context.settings.current.closeAfterExecute then
                    assetType.context.flow.close()
                else
                    assetType.context.flow.filterResults({clearText = true})
                end
                -- Return the actual result from the execute function
                return result
            elseif success then
                -- Execution didn't throw error but returned false - don't add to recents
                assetType.context.logger:logDebug('Execution returned false for asset: ' ..
                    (asset.searchText and asset.searchText[1] and asset.searchText[1].text or 'Unknown') ..
                    '.' .. (logMsg and (' Reason: ' .. logMsg) or ''))
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

function BaseAssetType:addInteraction(modifier, description, executeFunction)
    -- Add an interaction modifier to the class
    local class = getmetatable(self)
    if not class.interactionHints then
        class.interactionHints = {}
    end
    class.interactionHints[modifier] = { order = OD_TableLength(class.interactionHints), text = description }

    -- Store the execute function for this modifier
    if not class.executeFunctions then
        class.executeFunctions = {}
    end
    class.executeFunctions[modifier] = executeFunction

    self.context.logger:logDebug('Added interaction: ' .. description .. ' for modifier ' .. tostring(modifier))
end

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

        -- Default: not allowed in quickchain (can be overridden by subclasses)
        instance.allowInQuickChain = false

        -- Default: do not refresh item on project refresh
        instance.updateOnProjectRefresh = false

        -- Default: do not track item add Date
        instance.trackAddDate = false

        -- Default: do not track item add Date
        instance.allowMultiple = true

        instance.pluralName = inferredGroup
        -- Initialize class-level interactionHints if not already set
        if not class.interactionHints then
            class.interactionHints = {
                [0] = { order = 0, text = 'select %asset' }
            }
        end

        return instance
    end
end

BaseAssetType.assetActions = {
    -- key = function(self)
    --     return self.type .. ' ' .. self.load
    -- end,
    toggleFavorite = function(self)
        self.favorite = self.context.userdata:toggleAssetFavorite(self.key)

        -- Use the unified special groups marking function to handle group reassignment
        self.engine:markSpecialGroups()
        self.engine:sortAssets()
        self.context.flow.filterResults(nil, nil, { self }) -- Use multi-target to maintain selection on this asset
        return self.favorite == true
    end,
    -- Batch toggle favorites for multiple assets (more efficient than calling toggleFavorite multiple times)
    batchToggleFavorites = function(self, assets, willFavorite)
        local favorites = self.context.userdata.current.favorites
        local changed = false

        for _, asset in ipairs(assets) do
            if willFavorite and not asset.favorite then
                table.insert(favorites, 1, asset.key)
                asset.favorite = true
                changed = true
            elseif not willFavorite and asset.favorite then
                OD_RemoveValue(favorites, asset.key)
                asset.favorite = false
                changed = true
            end
        end

        if changed then
            self.context.userdata:save()
            -- Use the unified special groups marking function to handle group reassignment
            self.engine:markSpecialGroups()
            self.engine:sortAssets()
            -- Don't call filterResults here - let the caller handle it with target assets
        end

        return changed
    end,
    moveFavorite = function(self, targetPosition)
        local favorite = self.context.userdata.current.favorites
        local key = self.key

        -- Check if this asset is actually a favorite
        if not OD_HasValue(favorite, self.key) then
            self.context.logger:logError('Cannot move non-favorite asset: ' .. self.key)
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

        self.context.userdata:save()
        self.engine:markSpecialGroups()
        self.engine:sortAssets()
        self.context.flow.filterResults(nil, nil, { self }) -- Use multi-target to maintain selection on this asset

        self.context.logger:logDebug('Moved favorite "' ..
            key .. '" from position ' .. currentPosition .. ' to position ' .. targetPosition)
        return true
    end,
    addToRecents = function(self, filterResults)
        if filterResults == nil then filterResults = true end
        self.context.userdata:addAssetToRecents(self.key)

        -- Use the unified special groups marking function
        if filterResults then
            self.engine:markSpecialGroups()
            self.engine:sortAssets()
            self.context.flow.filterResults(nil, nil, { self }) -- Use multi-target to maintain selection on this asset
        end
    end,
    addTag = function(self, tag, saveToDB)
        local save = (saveToDB == nil) and true or saveToDB

        if not OD_HasValue(self.tags, tag.id) then
            table.insert(self.tags, tag.id)
            self.context.userdata:addTagToAsset(self.id, tag.id, save)
            self.context.engine:tagAssets() --update asset order
        end
    end,
    removeTag = function(self, tag, saveToDB)
        local save = (saveToDB == nil) and true or saveToDB

        if OD_HasValue(self.tags, tag.id) then
            OD_RemoveValue(self.tags, tag.id)
            self.context.userdata:removeTagFromAsset(self.id, tag.id, save)
        end
    end
}

function BaseAssetType:createAssetBase(params)
    return {
        class = self,
        id = tostring(params.type) .. ' ' .. tostring(params.load),
        type = params.type,
        load = params.load,
        searchText = params.searchText,
        group = params.group,
        pluralName = self.pluralName,
        allowMultiple = self.allowMultiple,
        getInteractionHintFor = function(asset, mods, context, contextData, count)
            return self.getInteractionHintFor(
                asset, mods, context, contextData, count)
        end,
        key = params.type .. ' ' .. params.load,
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
