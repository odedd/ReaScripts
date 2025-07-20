-- @noindex
-- Asset Type Manager

-- Asset Actions - shared functions for all asset types
local assetActions = {
    toggleFavorite = function(self)
        local favorite = self.db.app.tags.current.favorites
        local key = self.type .. ' ' .. self.load
        if OD_HasValue(favorite, key) then
            OD_RemoveValue(favorite, key)
            self.group = self.originalGroup
            self.originalGroup = nil
        else
            table.insert(favorite, key)
            self.originalGroup = self.group
            self.group = SPECIAL_GROUPS.FAVORITES
        end
        self.db.app.tags:save()
        self.db:sortAssets()
        return self.group == SPECIAL_GROUPS.FAVORITES
    end,
    addTag = function(self, tag, saveToDB)
        local save
        if save == nil then
            save = true
        else
            save = saveToDB
        end
        if not OD_HasValue(self.tags, tag.id) then
            table.insert(self.tags, tag.id)
            self.db.app.tags.current.taggedAssets[self.id] = self.db.app.tags.current.taggedAssets[self.id] or {}
            table.insert(self.db.app.tags.current.taggedAssets[self.id], tag.id)
            if save then self.db.app.tags:save() end
        end
    end,
    removeTag = function(self, tag, saveToDB)
        local save
        if save == nil then
            save = true
        else
            save = saveToDB
        end
        if OD_HasValue(self.tags, tag.id) then
            OD_RemoveValue(self.tags, tag.id)
            OD_RemoveValue(self.db.app.tags.current.taggedAssets[self.id], tag.id)
            if not next(self.db.app.tags.current.taggedAssets[self.id]) then self.db.app.tags.current.taggedAssets[self.id] = nil end
            if save then self.db.app.tags:save() end
        end
    end
}

AssetTypeManager = {}
AssetTypeManager.__index = AssetTypeManager

function AssetTypeManager:new(db)
    -- Create a minimal context object with only what asset types need
    local context = {
        -- Logger access
        logger = db.app.logger,
        
        -- Asset actions (shared functions)
        assetActions = assetActions,
        
        -- Settings access
        settings = db.app.settings,
        
        -- GUI context for ImGui operations
        gui = db.app.gui,
        
        -- FX data for plugin categorization
        fxDevelopers = db.fxDevelopers,
        pluginToCategories = db.pluginToCategories,
        pluginToFolders = db.pluginToFolders,
        
        -- Reference back to full db for cases where it's still needed
        db = db
    }
    
    local instance = setmetatable({}, self)
    instance.context = context
    instance.assetTypes = {}
    instance:loadAssetTypes()
    return instance
end

function AssetTypeManager:loadAssetTypes()
    -- Get the current script path to locate modules
    local info = debug.getinfo(1, "S")
    local scriptPath = info.source:match("@(.*[/\\])") or ""
    local assetTypesPath = scriptPath:gsub("lib[/\\]?$", "") .. "assetTypes/"
    
    self.context.logger:logDebug('Loading asset types from: ' .. assetTypesPath)
    
    -- Load BaseAssetType first
    dofile(assetTypesPath .. 'BaseAssetType.lua')
    
    -- Load manifest to get the list of modules and their IDs
    local manifestPath = assetTypesPath .. 'manifest.lua'
    local assetTypeDefinitions = dofile(manifestPath)
    
    self.context.logger:logDebug('Loaded manifest with ' .. #assetTypeDefinitions .. ' asset types')
    
    -- Load each module file according to manifest
    for _, definition in ipairs(assetTypeDefinitions) do
        self.context.logger:logDebug('Loading module: ' .. definition.file .. ' (ID: ' .. definition.id .. ')')
        dofile(assetTypesPath .. definition.file)
    end
    
    -- Store the manifest definitions for ordering and reference
    self.manifestDefinitions = assetTypeDefinitions
    
    -- Create instances of all asset types
    self:createAssetTypeInstances()
end

function AssetTypeManager:createAssetTypeInstances()
    -- Initialize asset type instances with focused context
    self.context.logger:logDebug('Creating asset type instances')
    
    -- Create a mapping from filename to manifest order for filter ordering
    local filenameToOrder = {}
    for i, definition in ipairs(self.manifestDefinitions) do
        filenameToOrder[definition.file] = i
    end
    
    for _, definition in ipairs(self.manifestDefinitions) do
        -- Derive class name from filename: "PluginAssetType.lua" -> "PluginAssetType"
        local className = definition.file:match("(.+)%.lua$")
        local AssetTypeClass = _G[className]  -- Get from global namespace
        
        if AssetTypeClass then
            local instance = AssetTypeClass.new(AssetTypeClass, self.context)
            
            -- Set filterOrder based on manifest order
            instance.filterOrder = filenameToOrder[definition.file]
            self.context.logger:logDebug('Set filterOrder=' .. instance.filterOrder .. ' for ' .. className .. ' (ID: ' .. definition.id .. ')')
            
            table.insert(self.assetTypes, instance)
            self.context.logger:logDebug('Created instance: ' .. (instance.name or className))
        else
            self.context.logger:logError('Asset type class not found: ' .. className)
        end
    end
end

function AssetTypeManager:getAssetTypeById(assetTypeId)
    for _, assetType in ipairs(self.assetTypes) do
        if assetType.assetTypeId == assetTypeId then
            return assetType
        end
    end
    return nil
end

function AssetTypeManager:getAssetTypeByClassName(className)
    for _, assetType in ipairs(self.assetTypes) do
        -- Check if this asset type corresponds to the given class name
        -- We can match by looking up the class name in ASSET_TYPE constant
        if ASSET_TYPE[className] == assetType.assetTypeId then
            return assetType
        end
    end
    return nil
end

function AssetTypeManager:buildFilterMenu()
    local filterMenu = {}
    
    for _, assetType in ipairs(self.assetTypes) do
        local menuEntry = assetType:getFilterMenuEntry()
        for key, value in pairs(menuEntry) do
            filterMenu[key] = value
        end
    end
    
    return filterMenu
end

function AssetTypeManager:assembleAllAssets()
    local assets = {}
    local count = 0
    
    for _, assetType in ipairs(self.assetTypes) do
        local assetData = assetType:getDataWithLogging()
        
        for _, data in ipairs(assetData) do
            local asset = assetType:assembleAsset(data)
            if asset then -- Asset may be nil if filtered out (e.g., plugin visibility)
                table.insert(assets, asset)
                count = count + 1
            end
        end
    end
    
    return assets, count
end

function AssetTypeManager:executeAsset(asset, context, contextData)
    if asset.execute then
        asset:execute(context, contextData)
    else
        self.context.logger:logError('Asset has no execute function: ' .. tostring(asset.type))
    end
end
