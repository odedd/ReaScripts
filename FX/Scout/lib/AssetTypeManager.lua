-- @noindex
-- Asset Type Manager

-- Asset Actions - shared functions for all asset types

AssetTypeManager = {}
AssetTypeManager.__index = AssetTypeManager

function AssetTypeManager:new(engine)
    -- Create a minimal context object with only what asset types need
    local context = {
        -- Logger access
        logger = engine.app.logger,

        -- Settings access
        settings = engine.app.settings,

        -- Userdata access
        userdata = engine.app.userdata,
        
        -- flow access
        flow = engine.app.flow,

        -- temp objects access
        temp = engine.app.temp,

        -- GUI context for ImGui operations
        gui = engine.app.gui,

        -- FX data for plugin categorization
        fxDevelopers = engine.fxDevelopers,
        pluginToCategories = engine.pluginToCategories,
        pluginToFolders = engine.pluginToFolders,

        -- Reference back to full engine for cases where it's still needed
        engine = engine
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
        local AssetTypeClass = _G[className] -- Get from global namespace

        if AssetTypeClass then
            local instance = AssetTypeClass.new(AssetTypeClass, self.context)

            -- Store the class name for visibility checking
            instance.className = className
            
            -- Set filterOrder based on manifest order
            instance.filterOrder = filenameToOrder[definition.file]
            self.context.logger:logDebug('Set filterOrder=' ..
                instance.filterOrder .. ' for ' .. className .. ' (ID: ' .. definition.id .. ')')

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
        -- Check if this asset type's class is visible
        local className = assetType.className
        if self.context.settings.current.groupVisibility[className] ~= false then
            local menuEntry = assetType:getFilterMenuEntry()
            for key, value in pairs(menuEntry) do
                filterMenu[key] = value
            end
        else
            self.context.logger:logDebug('Skipping filter menu entry for ' .. (assetType.name or 'unknown') .. ' - class "' .. className .. '" is not visible')
        end
    end

    return filterMenu
end

function AssetTypeManager:assembleAllAssets()
    local assets = {}
    local count = 0

    for _, assetType in ipairs(self.assetTypes) do
        -- Check if this asset type's class is visible using the class name as key
        local className = assetType.className
        if self.context.settings.current.groupVisibility[className] ~= false then
            local assetData = assetType:getDataWithLogging()

            for _, data in ipairs(assetData) do
                local asset = assetType:assembleAsset(data)
                if asset then -- Asset may be nil if filtered out (e.g., plugin visibility)
                    table.insert(assets, asset)
                    count = count + 1
                end
            end
        else
            self.context.logger:logDebug('Skipping asset type ' .. (assetType.name or 'unknown') .. ' - class "' .. className .. '" is not visible')
        end
    end

    return assets, count
end
