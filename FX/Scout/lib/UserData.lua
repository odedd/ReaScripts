-- @noindex

PB_UserData = OD_Settings:new({
    default = {
        -- Defineable in GUI
        favorites = {},
        tagInfo = {},
        taggedAssets = {},
        recents = {},
        presets = {},
        quickChains = {},
        tagIdCount = 7,
        presetIdCount = 0,
        quickChainIdCount = 0,
    },
    initial = {
        tagInfo = {
            [1] = { name = 'EQ', synonyms = { 'Equaliser' }, order = 1, parentId = TAGS_ROOT_PARENT },
            [2] = { name = 'Compressor', parentId = 4, order = 2 },
            [3] = { name = 'Spectral Processor', synonyms = { 'Resonance Surpressor' }, parentId = 1, order = 1 },
            [4] = { name = 'Dynamics', order = 2, parentId = TAGS_ROOT_PARENT },
            [5] = { name = 'Gate', parentId = 4, order = 1 },
            [6] = { name = 'Instruments', order = 3, parentId = TAGS_ROOT_PARENT },
            [7] = { name = 'Multiband', parentId = 2, order = 1 }
        },
        taggedAssets = {
            [ASSET_TYPE.PluginAssetType .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3"] = { 7, 3 },
            [ASSET_TYPE.PluginAssetType .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"] = { 1 },
            [ASSET_TYPE.PluginAssetType .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-C 2.vst3"] = { 2 },
            [ASSET_TYPE.PluginAssetType .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-G.vst3"] = { 5 }
        }
    },
    dfsetfile = Scr.dir .. Scr.no_ext .. ' tags.ini'
})

function PB_UserData:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Version and compatibility constants
local TAGS_FILE_VERSION = "1.0"
local COMPATIBLE_VERSIONS = {
    ["1.0"] = true, -- Current version
    -- Add older compatible versions here when needed
}

-- Version compatibility info
local VERSION_COMPATIBILITY_NOTES = {
    ["1.0"] = "Initial versioned format with plugin path mapping support",
}

-- Helper function to check if a version is compatible
local function isVersionCompatible(version)
    return version == nil or COMPATIBLE_VERSIONS[version] == true
end

-- Helper function to get compatibility info
local function getVersionInfo(version)
    return VERSION_COMPATIBILITY_NOTES[version] or "Unknown version"
end

function PB_UserData:getFileVersion()
    return TAGS_FILE_VERSION
end

function PB_UserData:isVersionCompatible(version)
    return isVersionCompatible(version)
end

function PB_UserData:export(filename)
    -- Export tags and taggedAssets to a file
    self.app.logger:logDebug('-- PB_UserData:export() to', filename)

    local file = io.open(filename, 'w')
    if not file then
        self.app.logger:logError('Failed to open file for writing', filename)
        return false
    end

    -- Export version info
    file:write('[version]\n')
    file:write(string.format('fileVersion=%s\n', TAGS_FILE_VERSION))
    file:write('\n')

    self.app.logger:logDebug('Written version', TAGS_FILE_VERSION)

    -- Export asset type mapping for cross-system compatibility
    file:write('[assetTypes]\n')
    local assetTypeCount = 0
    for className, id in pairs(ASSET_TYPE) do
        file:write(string.format('%d,%s\n', id, className))
        assetTypeCount = assetTypeCount + 1
    end
    file:write('\n')

    self.app.logger:logDebug('Exported asset types', assetTypeCount)

    -- Export tagInfo
    file:write('[tagInfo]\n')
    local tagCount = 0
    for id, tag in pairs(self.current.tagInfo) do
        -- Sanitize tag name and write with proper escaping
        local sanitizedName = OD_EscapeCSV(tag.name)
        file:write(string.format('%d,%s,%d,%d\n', id, sanitizedName, tag.parentId or 0, tag.order or 0))
        tagCount = tagCount + 1
    end
    file:write('\n')

    self.app.logger:logDebug('Exported tags', tagCount)

    -- Export taggedAssets
    file:write('[taggedAssets]\n')
    local assetCount = 0
    for asset, tags in pairs(self.current.taggedAssets) do
        -- Sanitize asset ID and write with proper escaping
        local sanitizedAsset = OD_EscapeCSV(asset)
        file:write(string.format('%s:%s\n', sanitizedAsset, table.concat(tags, ',')))
        assetCount = assetCount + 1
    end
    file:write('\n')

    -- Export presets
    file:write('[presets]\n')
    local presetsCount = 0
    for id, preset in pairs(self.current.presets) do
        -- Serialize preset filter using a simple key=value format
        local filterParts = {}
        for key, value in pairs(preset.filter) do
            if key == "tags" and type(value) == "table" then
                -- Special handling for tags (table of tagId=boolean)
                local tagParts = {}
                for tagId, positive in pairs(value) do
                    table.insert(tagParts, tagId .. "=" .. (positive and "1" or "0"))
                end
                if #tagParts > 0 then
                    table.insert(filterParts, "tags=" .. table.concat(tagParts, ";"))
                end
            elseif type(value) == "string" or type(value) == "number" then
                table.insert(filterParts, key .. "=" .. tostring(value))
            elseif type(value) == "boolean" then
                table.insert(filterParts, key .. "=" .. (value and "1" or "0"))
            end
        end
        local filterString = table.concat(filterParts, "&")

        local sanitizedName = OD_EscapeCSV(preset.name)
        local sanitizedWord = OD_EscapeCSV(preset.word or '')
        local sanitizedFilter = OD_EscapeCSV(filterString)
        file:write(string.format('%d,%s,%s,%s\n', id, sanitizedName, sanitizedWord, sanitizedFilter))
        presetsCount = presetsCount + 1
    end
    file:write('\n')

    self.app.logger:logDebug('Exported presets', presetsCount)

    -- Export Quick Chains
    file:write('[quickChains]\n')
    local quickChainsCount = 0
    for id, quickChain in pairs(self.current.quickChains) do
        -- Serialize Quick Chain items as comma-separated list
        local itemsString = table.concat(quickChain.items, ',')
        
        local sanitizedName = OD_EscapeCSV(quickChain.name)
        local sanitizedWord = OD_EscapeCSV(quickChain.word or '')
        local sanitizedItems = OD_EscapeCSV(itemsString)
        
        file:write(string.format('%d,%s,%s,%s\n', id, sanitizedName, sanitizedWord, sanitizedItems))
        quickChainsCount = quickChainsCount + 1
    end
    file:write('\n')

    self.app.logger:logDebug('Exported Quick Chains', quickChainsCount)

    -- Export favorites
    file:write('[favorites]\n')
    local favoritesCount = 0
    for _, favoriteAsset in ipairs(self.current.favorites) do
        -- Sanitize favorite asset ID and write with proper escaping
        local sanitizedFavorite = OD_EscapeCSV(favoriteAsset)
        file:write(sanitizedFavorite .. '\n')
        favoritesCount = favoritesCount + 1
    end

    file:close()

    self.app.logger:logDebug('Exported favorites', favoritesCount)
    self.app.logger:logInfo('Successfully exported ' ..
        tagCount ..
        ' tags, ' ..
        assetCount ..
        ' tagged assets, ' .. presetsCount .. ' presets, ' .. quickChainsCount .. ' Quick Chains, and ' .. favoritesCount .. ' favorites to ' .. filename)

    return true
end

function PB_UserData:import(args)
    -- mergeMode: true = merge with existing tags, false = replace all tags (default: false)
    args = args or {}
    local filename = args.filename or ''
    local mergeMode = args.mergeMode or false

    self.app.logger:logDebug('-- PB_UserData:import() from ' .. filename .. ' mergeMode: ' .. tostring(mergeMode))

    -- Check for AssetTypeManager that could cause "attempt to index a nil value" errors
    if not self.app.engine.assetTypeManager then
        local errorMsg = "self.app.engine.assetTypeManager is nil - make sure to call db:init() first"
        self.app.logger:logError(errorMsg)

        return { error = true, msg = errorMsg }
    end

    local file = io.open(filename, 'r')
    if not file then
        self.app.logger:logError('Failed to open file for reading', filename)

        return { error = true, msg = 'Failed to open file for reading' }
    end

    -- First pass: quickly count items per section
    local sectionCounts = {
        version = 0,
        assetTypes = 0,
        tagInfo = 0,
        taggedAssets = 0,
        presets = 0,
        quickChains = 0,
        favorites = 0
    }

    local currentSection = nil
    for line in file:lines() do
        if line:match("^%[version%]") then
            currentSection = "version"
        elseif line:match("^%[assetTypes%]") then
            currentSection = "assetTypes"
        elseif line:match("^%[tagInfo%]") then
            currentSection = "tagInfo"
        elseif line:match("^%[taggedAssets%]") then
            currentSection = "taggedAssets"
        elseif line:match("^%[presets%]") then
            currentSection = "presets"
        elseif line:match("^%[quickChains%]") then
            currentSection = "quickChains"
        elseif line:match("^%[favorites%]") then
            currentSection = "favorites"
        elseif currentSection and line ~= "" then
            sectionCounts[currentSection] = sectionCounts[currentSection] + 1
        end
    end

    -- Close and reopen file for actual parsing
    file:close()
    file = io.open(filename, 'r')
    if not file then
        self.app.logger:logError('Failed to reopen file for parsing', filename)
        return { error = true, msg = 'Failed to reopen file for parsing' }
    end

    self.app.logger:logDebug('Section counts:',
        'version: ' .. sectionCounts.version ..
        ', assetTypes: ' .. sectionCounts.assetTypes ..
        ', tagInfo: ' .. sectionCounts.tagInfo ..
        ', taggedAssets: ' .. sectionCounts.taggedAssets ..
        ', presets: ' .. sectionCounts.presets ..
        ', quickChains: ' .. sectionCounts.quickChains ..
        ', favorites: ' .. sectionCounts.favorites)

    local section = nil
    local importedTagInfo = {}
    local importedTaggedAssets = {}
    local importedPresets = {}    -- Track imported presets
    local importedQuickChains = {} -- Track imported Quick Chains
    local importedFavorites = {}  -- Track imported favorites
    local importedAssetTypes = {} -- Map of imported asset type ID -> class name
    local assetTypeMapping = {}   -- Map of imported asset type ID -> current system asset type ID
    local unmappedAssetTypes = {} -- Track asset types that couldn't be mapped
    local fileVersion = nil

    self.app.logger:logDebug('Parsing tags file...')

    local count = {}
    for line in file:lines() do
        if line:match("^%[version%]") then
            section = "version"
        elseif line:match("^%[assetTypes%]") then
            section = "assetTypes"
        elseif line:match("^%[tagInfo%]") then
            section = "tagInfo"
        elseif line:match("^%[taggedAssets%]") then
            section = "taggedAssets"
        elseif line:match("^%[presets%]") then
            section = "presets"
        elseif line:match("^%[quickChains%]") then
            section = "quickChains"
        elseif line:match("^%[favorites%]") then
            section = "favorites"
        elseif section == "version" and line ~= "" then
            local version = line:match("^fileVersion=(.+)$")
            if version then
                fileVersion = version
            end
        elseif section == "assetTypes" and line ~= "" then
            -- Parse asset type mapping: id,className
            local fields = OD_ParseCSVLine(line, ",")
            if #fields >= 2 then
                local importedId, className = fields[1], fields[2]
                if importedId and className and tonumber(importedId) then
                    importedAssetTypes[tonumber(importedId)] = className
                    -- Map to current system's asset type ID
                    local currentSystemId = ASSET_TYPE[className]
                    if currentSystemId then
                        assetTypeMapping[tonumber(importedId)] = currentSystemId
                        self.app.logger:logDebug('Asset type mapping',
                            className .. ': ' .. importedId .. ' -> ' .. currentSystemId)
                    else
                        -- Track unmapped asset types for reporting
                        table.insert(unmappedAssetTypes, {
                            importedId = tonumber(importedId),
                            className = className
                        })
                        self.app.logger:logError('Asset type not found in current system',
                            className .. ' (imported ID: ' .. importedId .. ')')
                    end
                else
                    self.app.logger:logError('Invalid assetTypes line format', line)
                end
            else
                self.app.logger:logError('Insufficient fields in assetTypes line', line)
            end
        elseif section == "tagInfo" and line ~= "" then
            -- Use safe CSV parsing for tag info
            local fields = OD_ParseCSVLine(line, ",")
            if #fields >= 4 then
                local id, name, parentId, order = fields[1], fields[2], fields[3], fields[4]
                if id and name and tonumber(id) then
                    importedTagInfo[tonumber(id)] = {
                        name = name, -- Already unescaped by OD_ParseCSVLine
                        parentId = tonumber(parentId) or 0,
                        order = tonumber(order) or 0
                    }
                else
                    self.app.logger:logError('Invalid tagInfo line format', line)
                end
            else
                self.app.logger:logError('Insufficient fields in tagInfo line', line)
            end
        elseif section == "taggedAssets" and line ~= "" then
            -- Use safe parsing for colon-separated asset line
            local colonPos = OD_FindUnescapedChar(line, ":")
            if colonPos then
                local asset = OD_UnescapeCSV(line:sub(1, colonPos - 1))
                local tagsStr = line:sub(colonPos + 1)

                if asset and tagsStr and asset ~= "" and tagsStr ~= "" then
                    -- Extract asset type ID from imported asset
                    local importedAssetTypeId = tonumber(asset:match("^(%d+)"))
                    if not importedAssetTypeId then
                        self.app.logger:logError('Could not extract asset type ID from asset', asset)
                        goto continue_asset_parsing
                    end

                    -- Check if we have a mapping for this asset type
                    local mappedAssetTypeId = assetTypeMapping[importedAssetTypeId]
                    if not mappedAssetTypeId then
                        -- Check if this is an unmapped asset type
                        local className = importedAssetTypes[importedAssetTypeId]
                        if className then
                            self.app.logger:logDebug('Skipping asset with unmapped asset type',
                                className .. ' (ID: ' .. importedAssetTypeId .. '): ' .. asset)
                        else
                            self.app.logger:logDebug('Skipping asset with unknown asset type ID',
                                importedAssetTypeId .. ': ' .. asset)
                        end
                        goto continue_asset_parsing
                    end

                    -- Extract basename for matching - different logic for different asset types
                    local imported_basename
                    local assetType = mappedAssetTypeId -- Use mapped asset type for processing

                    -- Check if this asset type is file-based
                    local targetAssetType = self.app.engine.assetTypeManager:getAssetTypeById(assetType)
                    local shouldMapBaseFilenames = targetAssetType and targetAssetType.shouldMapBaseFilenames

                    if shouldMapBaseFilenames then
                        -- For file-based assets, extract basename from path
                        imported_basename = asset:match("([^/\\]+)$")
                        -- For assets with <numbers (like WaveShell), remove the <numbers part
                        if imported_basename and imported_basename:find("<") then
                            imported_basename = imported_basename:match("^(.+)<")
                        end
                    else
                        -- For non-file-based assets, use the full identifier minus the asset type prefix
                        imported_basename = asset:match("^%d+%s+(.+)$")

                        -- Fallback: try to extract basename from path if the above didn't work
                        if not imported_basename then
                            imported_basename = asset:match("([^/\\]+)$")
                            -- For assets with <numbers (like WaveShell), remove the <numbers part
                            if imported_basename and imported_basename:find("<") then
                                imported_basename = imported_basename:match("^(.+)<")
                            end
                        end
                    end

                    if imported_basename then
                        local tag_ids = {}
                        for tag_id in tagsStr:gmatch("(%d+)") do
                            local numericId = tonumber(tag_id)
                            if numericId then
                                table.insert(tag_ids, numericId)
                            end
                        end
                        if #tag_ids > 0 then
                            -- Create remapped asset ID with the current system's asset type ID
                            local remappedAssetId = asset
                            if importedAssetTypeId and mappedAssetTypeId and importedAssetTypeId ~= mappedAssetTypeId then
                                remappedAssetId = asset:gsub("^" .. importedAssetTypeId, tostring(mappedAssetTypeId))
                                self.app.logger:logDebug('Remapped asset ID', asset .. ' -> ' .. remappedAssetId)
                            end

                            importedTaggedAssets[imported_basename] = {
                                tagIds = tag_ids,
                                originalAssetId = asset,
                                remappedAssetId = remappedAssetId,
                                mappedAssetType = mappedAssetTypeId
                            }
                        else
                            self.app.logger:logError('No valid tag IDs found in line', line)
                        end
                    else
                        self.app.logger:logError('Could not extract basename from asset', asset)
                    end

                    ::continue_asset_parsing::
                else
                    self.app.logger:logError('Invalid taggedAssets line format', line)
                end
            else
                self.app.logger:logError('No colon separator found in taggedAssets line', line)
            end
        elseif section == "presets" and line ~= "" then
            -- Parse presets: id,name,word,filter
            local fields = OD_ParseCSVLine(line, ",")
            if #fields >= 4 then
                local id, name, word, filterString = fields[1], fields[2], fields[3], fields[4]
                if id and name and tonumber(id) then
                    -- Parse filter string back to table format
                    local filter = {}
                    if filterString and filterString ~= "" then
                        for pair in filterString:gmatch("([^&]+)") do
                            local key, value = pair:match("([^=]+)=(.+)")
                            if key and value then
                                if key == "tags" then
                                    -- Special handling for tags
                                    filter.tags = {}
                                    for tagPair in value:gmatch("([^;]+)") do
                                        local tagId, positive = tagPair:match("([^=]+)=(.+)")
                                        if tagId and positive then
                                            filter.tags[tonumber(tagId)] = (positive == "1")
                                        end
                                    end
                                elseif tonumber(value) then
                                    filter[key] = tonumber(value)
                                elseif value == "1" then
                                    filter[key] = true
                                elseif value == "0" then
                                    filter[key] = false
                                else
                                    filter[key] = value
                                end
                            end
                        end
                    end

                    importedPresets[tonumber(id)] = {
                        name = name,
                        word = (word ~= "" and word or nil), -- Convert empty string to nil
                        filter = filter
                    }
                else
                    self.app.logger:logError('Invalid presets line format', line)
                end
            elseif #fields == 3 then
                -- Legacy format: id,name,filter (no magic word)
                local id, name, filterString = fields[1], fields[2], fields[3]
                if id and name and tonumber(id) then
                    -- Parse filter string back to table format
                    local filter = {}
                    if filterString and filterString ~= "" then
                        for pair in filterString:gmatch("([^&]+)") do
                            local key, value = pair:match("([^=]+)=(.+)")
                            if key and value then
                                if key == "tags" then
                                    -- Special handling for tags
                                    filter.tags = {}
                                    for tagPair in value:gmatch("([^;]+)") do
                                        local tagId, positive = tagPair:match("([^=]+)=(.+)")
                                        if tagId and positive then
                                            filter.tags[tonumber(tagId)] = (positive == "1")
                                        end
                                    end
                                elseif tonumber(value) then
                                    filter[key] = tonumber(value)
                                elseif value == "1" then
                                    filter[key] = true
                                elseif value == "0" then
                                    filter[key] = false
                                else
                                    filter[key] = value
                                end
                            end
                        end
                    end

                    importedPresets[tonumber(id)] = {
                        name = name,
                        word = nil, -- No magic word in legacy format
                        filter = filter
                    }
                else
                    self.app.logger:logError('Invalid presets line format', line)
                end
            else
                self.app.logger:logError('Insufficient fields in presets line', line)
            end
        elseif section == "quickChains" and line ~= "" then
            -- Parse Quick Chains: id,name,word,items
            local fields = OD_ParseCSVLine(line, ",")
            if #fields >= 4 then
                local id, name, word, itemsString = fields[1], fields[2], fields[3], fields[4]
                if id and name and tonumber(id) then
                    -- Parse items string back to array
                    local items = {}
                    if itemsString and itemsString ~= "" then
                        for item in itemsString:gmatch("([^,]+)") do
                            -- Filter out items that don't exist in the current system
                            -- Only include FX and FX Chain assets
                            local assetTypeId = tonumber(item:match("^(%d+)"))
                            if assetTypeId and (assetTypeId == ASSET_TYPE.PluginAssetType or assetTypeId == ASSET_TYPE.FXChainAssetType) then
                                table.insert(items, item)
                            end
                        end
                    end

                    importedQuickChains[tonumber(id)] = {
                        name = name,
                        word = (word ~= "" and word or nil), -- Convert empty string to nil
                        items = items
                    }
                else
                    self.app.logger:logError('Invalid quickChains line format', line)
                end
            else
                self.app.logger:logError('Insufficient fields in quickChains line', line)
            end
        elseif section == "favorites" and line ~= "" then
            -- Parse favorites: one asset ID per line
            local favoriteAsset = OD_UnescapeCSV(line)
            if favoriteAsset and favoriteAsset ~= "" then
                table.insert(importedFavorites, favoriteAsset)
            else
                self.app.logger:logError('Invalid favorites line format', line)
            end
        end
        if section then
            count[section] = (count[section] or 0) + 1
            if count[section] % YIELD_FREQUENCY == 0 or count[section] == (sectionCounts[section] or 0) then
                coroutine.yield({
                    progress = true,
                    msg = (T.PROGRESS.IMPORT.PARSING):format(section),
                    index = count[section],
                    total = sectionCounts[section] or 0
                })
            end
        end
    end
    file:close()

    local importedTagCount = 0
    for _ in pairs(importedTagInfo) do importedTagCount = importedTagCount + 1 end
    local importedAssetCount = 0
    for _ in pairs(importedTaggedAssets) do importedAssetCount = importedAssetCount + 1 end
    local importedPresetsCount = 0
    for _ in pairs(importedPresets) do importedPresetsCount = importedPresetsCount + 1 end
    local importedQuickChainsCount = 0
    for _ in pairs(importedQuickChains) do importedQuickChainsCount = importedQuickChainsCount + 1 end
    local importedFavoritesCount = #importedFavorites
    self.app.logger:logDebug('Parsed ' ..
        importedTagCount ..
        ' tags, ' ..
        importedAssetCount ..
        ' tagged assets, ' ..
        importedPresetsCount .. ' presets, ' .. 
        importedQuickChainsCount .. ' Quick Chains, and ' .. 
        importedFavoritesCount .. ' favorites from file')
    if fileVersion then
        self.app.logger:logDebug('File version', fileVersion)
    end

    -- Report unmapped asset types
    if #unmappedAssetTypes > 0 then
        self.app.logger:logInfo('Found ' .. #unmappedAssetTypes .. ' unmapped asset types in imported file:')
        for _, unmappedType in ipairs(unmappedAssetTypes) do
            self.app.logger:logInfo('  ' ..
                unmappedType.className ..
                ' (imported ID: ' .. unmappedType.importedId .. ') - not available in current system')
        end
    end

    -- Check version compatibility
    if not isVersionCompatible(fileVersion) then
        local errorMsg = string.format(
            "Incompatible tags file version: %s. Current version: %s\n%s",
            fileVersion or "unknown",
            TAGS_FILE_VERSION,
            fileVersion and getVersionInfo(fileVersion) or "No version information found"
        )

        self.app.logger:logError(errorMsg)
        return { error = true, msg = errorMsg }
    elseif fileVersion == nil then
        -- No version info found - assume legacy format
        self.app.logger:logInfo('No version information found in tags file. Assuming legacy format.')
    end

    -- Handle tagInfo based on merge mode
    if mergeMode then
        self.app.logger:logDebug('Processing import in merge mode')

        -- Helper function to get the full parent path for a tag
        local function getTagPath(tagId, tagInfoTable, idMappingTable, visitedIds)
            if not tagId or tagId == -1 or tagId == TAGS_ROOT_PARENT then
                return {}
            end

            -- Prevent infinite recursion by tracking visited IDs
            visitedIds = visitedIds or {}
            if visitedIds[tagId] then
                self.app.logger:logError('Circular reference detected in getTagPath for tag ID', tagId)
                return {}
            end
            visitedIds[tagId] = true

            local mappedId = idMappingTable and idMappingTable[tagId] or tagId
            local tag = tagInfoTable[mappedId]
            if not tag then
                return {}
            end

            local path = getTagPath(tag.parentId, tagInfoTable, idMappingTable, visitedIds)
            table.insert(path, tag.name)
            return path
        end

        -- Helper function to find existing tag with same name and parent path
        local function findExistingTag(importedTag, importedParentId, idMappingTable)
            local importedPath = getTagPath(importedParentId, importedTagInfo, idMappingTable, {})

            for existingTagId, existingTag in pairs(self.current.tagInfo) do
                if existingTag.name == importedTag.name then
                    local existingPath = getTagPath(existingTag.parentId, self.current.tagInfo, nil, {})

                    -- Compare paths
                    if #importedPath == #existingPath then
                        local pathMatch = true
                        for i = 1, #importedPath do
                            if importedPath[i] ~= existingPath[i] then
                                pathMatch = false
                                break
                            end
                        end
                        if pathMatch then
                            return existingTagId
                        end
                    end
                end
            end
            return nil
        end

        -- Helper function to ensure parent hierarchy exists and return the parent ID
        local function ensureParentExists(importedParentId, idMappingTable, nextNewIdRef, visitedIds)
            if not importedParentId or importedParentId == -1 or importedParentId == TAGS_ROOT_PARENT then
                return TAGS_ROOT_PARENT
            end

            -- Prevent infinite recursion by tracking visited IDs
            visitedIds = visitedIds or {}
            if visitedIds[importedParentId] then
                self.app.logger:logError('Circular reference detected for parent tag ID', importedParentId)
                return TAGS_ROOT_PARENT
            end
            visitedIds[importedParentId] = true

            -- Check if parent is already mapped
            if idMappingTable[importedParentId] then
                return idMappingTable[importedParentId]
            end

            -- Parent doesn't exist yet, we need to create it
            local importedParent = importedTagInfo[importedParentId]
            if not importedParent then
                self.app.logger:logError('Imported parent tag not found', importedParentId)
                return TAGS_ROOT_PARENT
            end

            -- Recursively ensure the parent's parent exists
            local grandParentId = ensureParentExists(importedParent.parentId, idMappingTable, nextNewIdRef, visitedIds)

            -- Check if this parent already exists in the target system by looking at already mapped parents only
            local existingParentId = nil
            if grandParentId then
                -- Build the imported parent path correctly by only using already mapped parents
                for existingTagId, existingTag in pairs(self.current.tagInfo) do
                    if existingTag.name == importedParent.name and existingTag.parentId == grandParentId then
                        existingParentId = existingTagId
                        break
                    end
                end
            end

            if existingParentId then
                idMappingTable[importedParentId] = existingParentId
                return existingParentId
            end

            -- Create the parent tag
            local newParentId = nextNewIdRef[1]
            nextNewIdRef[1] = nextNewIdRef[1] + 1

            self.current.tagInfo[newParentId] = {
                name = importedParent.name,
                parentId = grandParentId,
                order = importedParent.order or 0
            }

            idMappingTable[importedParentId] = newParentId
            self.app.logger:logDebug('Created parent tag "' .. importedParent.name .. '" with ID', newParentId)

            return newParentId
        end

        -- Merge mode: find existing tags with same name and parent path, create hierarchy as needed
        local idMapping = {}                                 -- maps imported ID to existing ID
        local nextNewIdRef = { self.current.tagIdCount + 1 } -- Use table for reference
        local newTagsCount = 0
        local existingTagsCount = 0
        for importedId, importedTag in pairs(importedTagInfo) do
            -- First ensure the parent hierarchy exists
            local mappedParentId = ensureParentExists(importedTag.parentId, idMapping, nextNewIdRef, {})

            -- Look for existing tag with same name and parent path
            local existingId = findExistingTag(importedTag, importedTag.parentId, idMapping)

            if existingId then
                -- Tag exists, use existing ID
                idMapping[importedId] = existingId
                existingTagsCount = existingTagsCount + 1
                local pathStr = table.concat(getTagPath(importedTag.parentId, importedTagInfo, idMapping, {}), " > ")
                self.app.logger:logDebug('Tag "' ..
                    importedTag.name ..
                    '" at path "' .. pathStr .. '" already exists, mapping ' .. importedId .. ' -> ' .. existingId)
            else
                -- New tag, assign new ID
                idMapping[importedId] = nextNewIdRef[1]
                self.current.tagInfo[nextNewIdRef[1]] = {
                    name = importedTag.name,
                    parentId = mappedParentId,
                    order = importedTag.order or 0
                }
                newTagsCount = newTagsCount + 1
                local pathStr = table.concat(getTagPath(mappedParentId, self.current.tagInfo, nil, {}), " > ")
                self.app.logger:logDebug(
                    'Adding new tag "' .. importedTag.name .. '" at path "' .. pathStr .. '" with ID', nextNewIdRef[1])
                nextNewIdRef[1] = nextNewIdRef[1] + 1
            end
            local count = newTagsCount + existingTagsCount
            if count % YIELD_FREQUENCY == 0 or count == sectionCounts.tagInfo then
                coroutine.yield({
                    progress = true,
                    msg = T.PROGRESS.IMPORT.MAPPING_TAGS,
                    index = count,
                    total = sectionCounts.tagInfo
                })
            end
        end

        -- Update idCount
        self.current.tagIdCount = nextNewIdRef[1] - 1

        self.app.logger:logDebug('Merge mode: mapped ' ..
            existingTagsCount .. ' existing tags, ' .. newTagsCount .. ' new tags added')

        -- Remap tag IDs in imported tagged assets
        local remappedImportedTaggedAssets = {}
        for basename, assetData in pairs(importedTaggedAssets) do
            local remappedTagIds = {}
            for _, tagId in ipairs(assetData.tagIds) do
                if idMapping[tagId] then
                    table.insert(remappedTagIds, idMapping[tagId])
                end
            end
            if #remappedTagIds > 0 then
                remappedImportedTaggedAssets[basename] = {
                    tagIds = remappedTagIds,
                    originalAssetId = assetData.originalAssetId
                }
            end
        end
        importedTaggedAssets = remappedImportedTaggedAssets
    else
        self.app.logger:logDebug('Processing import in replace mode')

        -- Replace mode: completely replace tagInfo
        self.current.tagInfo = importedTagInfo

        -- Update tagIdCount to be higher than any imported ID
        local maxId = 0
        for id, _ in pairs(importedTagInfo) do
            if id > maxId then maxId = id end
        end
        self.current.tagIdCount = maxId

        local tagCount = 0
        for _ in pairs(importedTagInfo) do tagCount = tagCount + 1 end
        self.app.logger:logDebug('Replace mode: replaced all tags with ' .. tagCount .. ' imported tags')
    end

    -- Remap imported taggedAssets to your system's asset IDs
    local remappedTaggedAssets = {}
    local mappedAssetsCount = 0
    local skippedAssetsCount = 0
    local skippedAssets = {} -- Table to track unimported assets with reasons
    local assetTypeCounts = {
        [ASSET_TYPE.PluginAssetType] = { mapped = 0, skipped = 0 },
        [ASSET_TYPE.FXChainAssetType] = { mapped = 0, skipped = 0 },
        [ASSET_TYPE.TrackTemplateAssetType] = { mapped = 0, skipped = 0 },
        [ASSET_TYPE.TrackAssetType] = { mapped = 0, skipped = 0 },
        [ASSET_TYPE.ActionAssetType] = { mapped = 0, skipped = 0 }
    }

    self.app.logger:logDebug('Remapping tagged assets by searching all system assets...')

    -- Cache asset data per asset type to avoid repeated scanning and logging
    local assetTypeDataCache = {}
    local function getAssetTypeData(assetType)
        if not assetTypeDataCache[assetType] then
            local targetAssetType = self.app.engine.assetTypeManager:getAssetTypeById(assetType)
            if targetAssetType then
                assetTypeDataCache[assetType] = {
                    assetType = targetAssetType,
                    data = targetAssetType:getDataWithLogging()
                }
                self.app.logger:logDebug('Cached asset data for asset type', assetType)
            else
                self.app.logger:logError('Could not find asset type in AssetTypeManager for ID', assetType)
                assetTypeDataCache[assetType] = nil
            end
        end
        return assetTypeDataCache[assetType]
    end

    -- Helper function to map imported asset IDs to current system asset IDs (DRY principle)
    local function mapImportedAssetToSystem(importedAssetId)
        -- Extract asset type from imported asset ID
        local importedAssetTypeId = tonumber(importedAssetId:match("^(%d+)"))
        if not importedAssetTypeId then
            return nil, nil
        end

        -- Get mapped asset type ID
        local mappedAssetTypeId = assetTypeMapping[importedAssetTypeId] or importedAssetTypeId

        -- Extract the full path/identifier and basename from imported asset
        local importedFullPath = importedAssetId:match("^%d+%s+(.+)$")
        if not importedFullPath then
            return nil, nil
        end

        -- Search for matching system asset using cached asset data
        local cachedAssetTypeData = getAssetTypeData(mappedAssetTypeId)
        if not cachedAssetTypeData then
            return nil, mappedAssetTypeId
        end

        -- For file-based assets, try exact path match first, then basename fallback
        if cachedAssetTypeData.assetType.shouldMapBaseFilenames then
            -- Step 1: Try exact path match
            for _, data in ipairs(cachedAssetTypeData.data) do
                local asset = cachedAssetTypeData.assetType:assembleAsset(data)
                if asset then
                    local systemFullPath = asset.id:match("^%d+%s+(.+)$")
                    if systemFullPath == importedFullPath then
                        self.app.logger:logDebug('✓ Exact path match found for "' .. importedFullPath .. '"')
                        return asset.id, mappedAssetTypeId
                    end
                end
            end

            -- Step 2: Fallback to basename matching only if the exact path doesn't exist
            local importedBasename = importedFullPath:match("([^/\\]+)$")
            if importedBasename and importedBasename:find("<") then
                importedBasename = importedBasename:match("^(.+)<")
            end

            if importedBasename then
                for _, data in ipairs(cachedAssetTypeData.data) do
                    local asset = cachedAssetTypeData.assetType:assembleAsset(data)
                    if asset then
                        local systemFullPath = asset.id:match("^%d+%s+(.+)$")
                        local systemBasename = systemFullPath and systemFullPath:match("([^/\\]+)$")
                        if systemBasename and systemBasename:find("<") then
                            systemBasename = systemBasename:match("^(.+)<")
                        end

                        if systemBasename == importedBasename then
                            self.app.logger:logDebug('✓ Basename fallback match: "' ..
                                importedFullPath .. '" -> "' .. systemFullPath .. '"')
                            return asset.id, mappedAssetTypeId
                        end
                    end
                end
            end
        elseif not cachedAssetTypeData.assetType.shouldMapBaseFilenames then
            -- For non-file-based assets, try exact identifier match
            for _, data in ipairs(cachedAssetTypeData.data) do
                local asset = cachedAssetTypeData.assetType:assembleAsset(data)
                if asset then
                    local systemIdentifier = asset.id:match("^%d+%s+(.+)$")
                    if systemIdentifier == importedFullPath then
                        self.app.logger:logDebug('✓ Exact identifier match found for "' .. importedFullPath .. '"')
                        return asset.id, mappedAssetTypeId
                    end
                end
            end
        end

        return nil, mappedAssetTypeId
    end
    local count = 0
    for imported_basename, assetData in pairs(importedTaggedAssets) do
        count = count + 1
        self.app.logger:logDebug('Processing imported asset: basename="' ..
            imported_basename .. '" originalAssetId="' .. assetData.originalAssetId .. '"')

        -- Use mapped asset type if available, fallback to extracted from original
        local assetType = assetData.mappedAssetType or tonumber(assetData.originalAssetId:match("^(%d+)"))
        if not assetType then
            self.app.logger:logDebug('✗ Could not determine asset type from: "' .. assetData.originalAssetId .. '"')
            goto continue
        end

        if assetData.mappedAssetType then
            self.app.logger:logDebug('Using mapped asset type', assetType .. ' for ' .. imported_basename)
        end

        -- Use the improved mapping function that tries exact path first, then basename fallback
        local matchedSystemAssetId, mappedAssetType = mapImportedAssetToSystem(assetData.remappedAssetId or
            assetData.originalAssetId)

        if matchedSystemAssetId then
            mappedAssetsCount = mappedAssetsCount + 1

            -- Update type counts using the mapped asset type
            if assetTypeCounts[mappedAssetType] then
                assetTypeCounts[mappedAssetType].mapped = assetTypeCounts[mappedAssetType].mapped + 1
            end

            self.app.logger:logDebug('✓ Mapped asset "' ..
                imported_basename .. '" to system asset "' .. matchedSystemAssetId .. '"')

            if mergeMode then
                -- In merge mode, combine with existing tags for this asset
                local existingTags = self.current.taggedAssets[matchedSystemAssetId] or {}
                local combinedTags = {}

                -- Add existing tags
                for _, tagId in ipairs(existingTags) do
                    if not OD_HasValue(combinedTags, tagId) then
                        table.insert(combinedTags, tagId)
                    end
                end

                -- Add imported tags
                for _, tagId in ipairs(assetData.tagIds) do
                    if not OD_HasValue(combinedTags, tagId) then
                        table.insert(combinedTags, tagId)
                    end
                end

                remappedTaggedAssets[matchedSystemAssetId] = combinedTags
            else
                -- In replace mode, just use imported tags
                remappedTaggedAssets[matchedSystemAssetId] = assetData.tagIds
            end
        else
            -- Asset could not be mapped to an existing system asset
            local cachedAssetTypeData = getAssetTypeData(mappedAssetType or assetType)
            local shouldImportUnmapped = cachedAssetTypeData and
                not cachedAssetTypeData.assetType.requiresMappingOnImport

            if shouldImportUnmapped then
                -- Import asset even without mapping (e.g., for tracks that may be created later)
                mappedAssetsCount = mappedAssetsCount + 1

                -- Update type counts using the mapped asset type
                local finalAssetType = mappedAssetType or assetType
                if assetTypeCounts[finalAssetType] then
                    assetTypeCounts[finalAssetType].mapped = assetTypeCounts[finalAssetType].mapped + 1
                end

                -- Use the remapped asset ID from the import data
                local unmappedAssetId = assetData.remappedAssetId or assetData.originalAssetId
                self.app.logger:logDebug('✓ Imported unmapped asset "' ..
                    imported_basename .. '" as "' .. unmappedAssetId .. '" (will apply when asset becomes available)')

                if mergeMode then
                    -- In merge mode, combine with existing tags for this asset
                    local existingTags = self.current.taggedAssets[unmappedAssetId] or {}
                    local combinedTags = {}

                    -- Add existing tags
                    for _, tagId in ipairs(existingTags) do
                        if not OD_HasValue(combinedTags, tagId) then
                            table.insert(combinedTags, tagId)
                        end
                    end

                    -- Add imported tags
                    for _, tagId in ipairs(assetData.tagIds) do
                        if not OD_HasValue(combinedTags, tagId) then
                            table.insert(combinedTags, tagId)
                        end
                    end

                    remappedTaggedAssets[unmappedAssetId] = combinedTags
                else
                    -- In replace mode, just use imported tags
                    remappedTaggedAssets[unmappedAssetId] = assetData.tagIds
                end
            else
                -- Skip assets that require mapping but couldn't be mapped
                skippedAssetsCount = skippedAssetsCount + 1

                local finalAssetType = mappedAssetType or assetType
                self.app.logger:logDebug('✗ Asset "' ..
                    imported_basename .. '" (type ' .. (finalAssetType or "unknown") .. ') not found in system assets')

                -- Get asset type name from the actual asset type definition
                local assetTypeName = "unknown"
                local cachedAssetTypeData = getAssetTypeData(finalAssetType)
                if cachedAssetTypeData and cachedAssetTypeData.assetType then
                    assetTypeName = cachedAssetTypeData.assetType.name or "unknown"
                end

                -- Update skip counts
                if assetTypeCounts[finalAssetType] then
                    assetTypeCounts[finalAssetType].skipped = assetTypeCounts[finalAssetType].skipped + 1
                end

                -- Record the skipped asset with its reason
                table.insert(skippedAssets, {
                    basename = imported_basename,
                    originalAssetId = assetData.originalAssetId,
                    reason = IMPORT_SKIP_REASON.ASSET_NOT_FOUND,
                    assetTypeGuess = assetTypeName
                })
            end
        end
        if count % YIELD_FREQUENCY == 0 or count == sectionCounts.taggedAssets then
            coroutine.yield({
                progress = true,
                msg = T.PROGRESS.IMPORT.MAPPING_ITEMS,
                index = count,
                total = sectionCounts.taggedAssets
            })
        end
        ::continue::
    end

    if mergeMode then
        -- In merge mode, preserve existing tagged assets that weren't imported
        local preservedAssetsCount = 0
        for assetId, tags in pairs(self.current.taggedAssets) do
            if not remappedTaggedAssets[assetId] then
                remappedTaggedAssets[assetId] = tags
                preservedAssetsCount = preservedAssetsCount + 1
            end
        end

        self.app.logger:logDebug('Preserved existing tagged assets not in import', preservedAssetsCount)
    end

    self.current.taggedAssets = remappedTaggedAssets

    local finalAssetCount = 0
    for _ in pairs(self.current.taggedAssets) do finalAssetCount = finalAssetCount + 1 end

    -- Log detailed breakdown by asset type
    self.app.logger:logInfo('Import successful: ' ..
        mappedAssetsCount ..
        ' assets mapped, ' .. skippedAssetsCount .. ' assets skipped, total tagged assets: ' .. finalAssetCount)

    -- Log asset type mapping information
    local mappingCount = 0
    for importedId, currentId in pairs(assetTypeMapping) do
        mappingCount = mappingCount + 1
    end
    if mappingCount > 0 then
        self.app.logger:logInfo('Asset type mappings applied', mappingCount)
        for importedId, currentId in pairs(assetTypeMapping) do
            local className = importedAssetTypes[importedId] or "unknown"
            self.app.logger:logDebug('Asset type mapping', className .. ': ' .. importedId .. ' -> ' .. currentId)
        end
    else
        self.app.logger:logDebug('No asset type mappings needed (same system or legacy file)')
    end

    for assetType, counts in pairs(assetTypeCounts) do
        if counts.mapped > 0 or counts.skipped > 0 then
            -- Get the actual asset type name from the definition
            local typeName = "unknown"
            local cachedAssetTypeData = getAssetTypeData(assetType)
            if cachedAssetTypeData and cachedAssetTypeData.assetType then
                -- Use the plural form (group name) if available, otherwise the singular name
                typeName = cachedAssetTypeData.assetType.group or cachedAssetTypeData.assetType.name or "unknown"
            end

            if counts.mapped > 0 then
                self.app.logger:logDebug('Mapped ' .. typeName, counts.mapped)
            end
            if counts.skipped > 0 then
                self.app.logger:logDebug('Skipped ' .. typeName, counts.skipped)
            end
        end
    end

    -- Process imported favorites
    local mappedFavoritesCount = 0
    local skippedFavoritesCount = 0
    local finalFavorites = {}

    if mergeMode then
        -- In merge mode, preserve existing favorites
        for _, favoriteAsset in ipairs(self.current.favorites) do
            if not OD_HasValue(finalFavorites, favoriteAsset) then
                table.insert(finalFavorites, favoriteAsset)
            end
        end
    end

    -- Map imported favorites to current system assets
    for _, importedFavorite in ipairs(importedFavorites) do
        local mappedAssetId, mappedAssetType = mapImportedAssetToSystem(importedFavorite)

        if mappedAssetId then
            mappedFavoritesCount = mappedFavoritesCount + 1

            -- Add to favorites if not already present
            if not OD_HasValue(finalFavorites, mappedAssetId) then
                table.insert(finalFavorites, mappedAssetId)
                self.app.logger:logDebug('✓ Mapped favorite "' .. importedFavorite .. '" to "' .. mappedAssetId .. '"')
            else
                self.app.logger:logDebug('✓ Favorite "' .. mappedAssetId .. '" already exists, skipping duplicate')
            end
        else
            skippedFavoritesCount = skippedFavoritesCount + 1

            -- Check if we should import unmapped favorites (e.g., for tracks)
            local importedAssetTypeId = tonumber(importedFavorite:match("^(%d+)"))
            local mappedAssetTypeId = assetTypeMapping[importedAssetTypeId] or importedAssetTypeId
            local cachedAssetTypeData = mappedAssetTypeId and getAssetTypeData(mappedAssetTypeId)
            local shouldImportUnmapped = cachedAssetTypeData and
                not cachedAssetTypeData.assetType.requiresMappingOnImport

            if shouldImportUnmapped then
                -- Import unmapped favorite (will apply when asset becomes available)
                local remappedAssetId = importedFavorite
                if importedAssetTypeId and mappedAssetTypeId and importedAssetTypeId ~= mappedAssetTypeId then
                    remappedAssetId = importedFavorite:gsub("^" .. importedAssetTypeId, tostring(mappedAssetTypeId))
                end

                if not OD_HasValue(finalFavorites, remappedAssetId) then
                    table.insert(finalFavorites, remappedAssetId)
                    mappedFavoritesCount = mappedFavoritesCount + 1
                    skippedFavoritesCount = skippedFavoritesCount - 1
                    self.app.logger:logDebug('✓ Imported unmapped favorite "' ..
                        remappedAssetId .. '" (will apply when asset becomes available)')
                end
            else
                self.app.logger:logDebug('✗ Favorite "' .. importedFavorite .. '" not found in system assets')
            end
        end
    end

    -- Update favorites
    self.current.favorites = finalFavorites

    self.app.logger:logInfo('Favorites import: ' ..
        mappedFavoritesCount .. ' mapped, ' .. skippedFavoritesCount .. ' skipped, total favorites: ' .. #finalFavorites)

    -- Process imported presets
    local mappedPresetsCount = 0
    local skippedPresetsCount = 0
    local finalPresets = {}

    if mergeMode then
        -- In merge mode, preserve existing presets
        for id, preset in pairs(self.current.presets) do
            finalPresets[id] = preset
        end
    end

    -- Helper function to validate filter dependencies
    local function validateFilterDependencies(filter)
        local issues = {}

        if filter.fxFolderId then
            -- Check if FX folder exists (this would need folder validation logic)
            -- For now, we'll assume folder validation happens at runtime
        end

        if filter.fxCategory then
            -- Check if category exists in current system
            -- Categories are dynamic, so we'll validate at runtime
        end

        if filter.fxDeveloper then
            -- Check if developer exists in current system
            -- Developers are dynamic, so we'll validate at runtime
        end

        if filter.tags then
            -- Check if all referenced tags exist
            for tagId, _ in pairs(filter.tags) do
                if not self.current.tagInfo[tagId] then
                    table.insert(issues, "Missing tag ID: " .. tagId)
                end
            end
        end

        return issues
    end

    for importedId, importedPreset in pairs(importedPresets) do
        -- Validate filter dependencies
        local issues = validateFilterDependencies(importedPreset.filter)

        if #issues > 0 then
            skippedPresetsCount = skippedPresetsCount + 1
            self.app.logger:logDebug('✗ Skipped preset "' .. importedPreset.name .. '": ' .. table.concat(issues, ", "))
        else
            -- Import preset
            local newId = importedId
            local existingPresetId = nil

            if mergeMode then
                -- In merge mode, check if a preset with the same name already exists
                for id, preset in pairs(finalPresets) do
                    if preset.name == importedPreset.name then
                        existingPresetId = id
                        break
                    end
                end

                if existingPresetId then
                    -- Update existing preset with same name
                    newId = existingPresetId
                    self.app.logger:logDebug('⟳ Updating existing preset "' ..
                        importedPreset.name .. '" (ID ' .. newId .. ')')
                else
                    -- Find next available ID if no name conflict exists
                    while finalPresets[newId] do
                        newId = newId + 1
                    end
                end
            end

            finalPresets[newId] = {
                id = newId,
                name = importedPreset.name,
                word = importedPreset.word,
                filter = OD_DeepCopy(importedPreset.filter),
            }

            mappedPresetsCount = mappedPresetsCount + 1
            if existingPresetId then
                self.app.logger:logDebug('✓ Updated preset "' .. importedPreset.name .. '" with ID ' .. newId)
            else
                self.app.logger:logDebug('✓ Imported preset "' .. importedPreset.name .. '" with ID ' .. newId)
            end
        end
    end

    -- Update presets and presetIdCount
    self.current.presets = finalPresets

    -- Update presetIdCount to be higher than any preset ID
    local maxId = self.current.presetIdCount or 0
    for id, _ in pairs(finalPresets) do
        if id > maxId then maxId = id end
    end
    if maxId > self.current.presetIdCount then
        self.current.presetIdCount = maxId
    end

    self.app.logger:logInfo('Presets import: ' ..
        mappedPresetsCount ..
        ' imported, ' .. skippedPresetsCount .. ' skipped, total presets: ' .. OD_TableLength(finalPresets))

    -- Process imported Quick Chains
    local mappedQuickChainsCount = 0
    local skippedQuickChainsCount = 0
    local finalQuickChains = {}

    if mergeMode then
        -- In merge mode, preserve existing Quick Chains
        for id, quickChain in pairs(self.current.quickChains) do
            finalQuickChains[id] = quickChain
        end
    end

    for importedId, importedQuickChain in pairs(importedQuickChains) do
        -- Enhanced magic word conflict checking
        local hasConflict = false
        local conflictDetails = ""
        
        if importedQuickChain.word and importedQuickChain.word ~= "" then
            -- Check for conflicts with existing presets
            for _, preset in pairs(finalPresets) do
                if preset.word and preset.word:upper() == importedQuickChain.word:upper() then
                    hasConflict = true
                    conflictDetails = 'magic word "' .. importedQuickChain.word .. '" conflicts with existing preset "' .. preset.name .. '"'
                    break
                end
            end
            
            -- Check for conflicts with existing Quick Chains (only if no preset conflict found)
            if not hasConflict then
                for id, quickChain in pairs(finalQuickChains) do
                    if quickChain.word and quickChain.word:upper() == importedQuickChain.word:upper() then
                        if mergeMode then
                            -- In merge mode, check if it's not the same Quick Chain by name
                            if quickChain.name ~= importedQuickChain.name then
                                hasConflict = true
                                conflictDetails = 'magic word "' .. importedQuickChain.word .. '" conflicts with existing Quick Chain "' .. quickChain.name .. '"'
                                break
                            end
                        else
                            -- In replace mode, check if it's not the same ID
                            if id ~= importedId then
                                hasConflict = true
                                conflictDetails = 'magic word "' .. importedQuickChain.word .. '" conflicts with existing Quick Chain "' .. quickChain.name .. '"'
                                break
                            end
                        end
                    end
                end
            end
        end
        
        if hasConflict then
            skippedQuickChainsCount = skippedQuickChainsCount + 1
            self.app.logger:logDebug('✗ Skipped Quick Chain "' .. importedQuickChain.name .. '": ' .. conflictDetails)
            goto continue_quickchain
        end
        
        -- Map Quick Chain items to existing assets where possible
        local mappedItems = {}
        local skippedItems = 0
        
        for _, item in ipairs(importedQuickChain.items) do
            local mappedAssetId, mappedAssetType = mapImportedAssetToSystem(item)
            if mappedAssetId then
                table.insert(mappedItems, mappedAssetId)
                self.app.logger:logDebug('✓ Mapped Quick Chain item: "' .. item .. '" -> "' .. mappedAssetId .. '"')
            else
                -- Skip items that are missing from the receiving system
                skippedItems = skippedItems + 1
                self.app.logger:logDebug('✗ Skipped missing Quick Chain item: "' .. item .. '"')
            end
        end
        
        -- Only import the Quick Chain if it has at least one valid item
        if #mappedItems == 0 then
            skippedQuickChainsCount = skippedQuickChainsCount + 1
            self.app.logger:logDebug('✗ Skipped Quick Chain "' .. importedQuickChain.name .. '": no valid items found (all ' .. skippedItems .. ' items missing from system)')
            goto continue_quickchain
        end
        
        -- Import Quick Chain
        local newId = importedId
        local existingQuickChainId = nil

        if mergeMode then
            -- In merge mode, check if a Quick Chain with the same name already exists
            for id, quickChain in pairs(finalQuickChains) do
                if quickChain.name == importedQuickChain.name then
                    existingQuickChainId = id
                    break
                end
            end

            if existingQuickChainId then
                -- Update existing Quick Chain with same name
                newId = existingQuickChainId
                self.app.logger:logDebug('⟳ Updating existing Quick Chain "' ..
                    importedQuickChain.name .. '" (ID ' .. newId .. ')')
            else
                -- Find next available ID if no name conflict exists
                while finalQuickChains[newId] do
                    newId = newId + 1
                end
            end
        end

        finalQuickChains[newId] = {
            id = newId,
            name = importedQuickChain.name,
            word = importedQuickChain.word,
            items = mappedItems, -- Use mapped items instead of original items
        }

        mappedQuickChainsCount = mappedQuickChainsCount + 1
        
        if skippedItems > 0 then
            self.app.logger:logDebug('✓ Imported Quick Chain "' .. importedQuickChain.name .. '" with ' .. #mappedItems .. ' items (' .. skippedItems .. ' items skipped)')
        else
            self.app.logger:logDebug('✓ Imported Quick Chain "' .. importedQuickChain.name .. '" with ' .. #mappedItems .. ' items')
        end
        
        if existingQuickChainId then
            self.app.logger:logDebug('✓ Updated Quick Chain "' .. importedQuickChain.name .. '" with ID ' .. newId)
        else
            self.app.logger:logDebug('✓ Imported Quick Chain "' .. importedQuickChain.name .. '" with ID ' .. newId)
        end

        ::continue_quickchain::
    end

    -- Update Quick Chains and quickChainIdCount
    self.current.quickChains = finalQuickChains

    -- Update quickChainIdCount to be higher than any Quick Chain ID
    local maxQuickChainId = self.current.quickChainIdCount or 0
    for id, _ in pairs(finalQuickChains) do
        if id > maxQuickChainId then maxQuickChainId = id end
    end
    if maxQuickChainId > self.current.quickChainIdCount then
        self.current.quickChainIdCount = maxQuickChainId
    end

    self.app.logger:logInfo('Quick Chains import: ' ..
        mappedQuickChainsCount ..
        ' imported, ' .. skippedQuickChainsCount .. ' skipped, total Quick Chains: ' .. OD_TableLength(finalQuickChains))

    -- Final magic word conflict check across presets and Quick Chains
    local magicWordConflicts = {}
    local conflictCount = 0
    
    -- Collect all magic words from presets
    for presetId, preset in pairs(finalPresets) do
        if preset.word and preset.word ~= "" then
            local wordUpper = preset.word:upper()
            if not magicWordConflicts[wordUpper] then
                magicWordConflicts[wordUpper] = {}
            end
            table.insert(magicWordConflicts[wordUpper], {
                type = "preset",
                id = presetId,
                name = preset.name
            })
        end
    end
    
    -- Collect all magic words from Quick Chains and check for conflicts
    for quickChainId, quickChain in pairs(finalQuickChains) do
        if quickChain.word and quickChain.word ~= "" then
            local wordUpper = quickChain.word:upper()
            if not magicWordConflicts[wordUpper] then
                magicWordConflicts[wordUpper] = {}
            end
            table.insert(magicWordConflicts[wordUpper], {
                type = "quickChain",
                id = quickChainId,
                name = quickChain.name
            })
        end
    end
    
    -- Report any conflicts found
    for word, conflicts in pairs(magicWordConflicts) do
        if #conflicts > 1 then
            conflictCount = conflictCount + 1
            local conflictNames = {}
            for _, conflict in ipairs(conflicts) do
                table.insert(conflictNames, conflict.type .. ' "' .. conflict.name .. '"')
            end
            self.app.logger:logWarning('Magic word conflict detected: "' .. word .. '" is used by: ' .. table.concat(conflictNames, ", "))
        end
    end
    
    if conflictCount > 0 then
        self.app.logger:logWarning('Found ' .. conflictCount .. ' magic word conflicts after import. Some magic words may not work as expected.')
    else
        self.app.logger:logDebug('No magic word conflicts detected after import')
    end

    self:save()

    -- Notify engine to refresh its runtime data after import
    if self.app.engine then
        self.app.engine:getTags(true)    -- Pass true to reassemble tag filter assets
        self.app.engine:getPresets(true) -- Refresh presets
        self.app.engine:assembleAssets()
    end

    -- Trigger a refresh of the search results to show updated tags
    if self.app.flow then
        self.app.flow.filterResults()
    end

    local msg = (mergeMode and T.PROGRESS.IMPORT.SUCCESS_MERGE or T.PROGRESS.IMPORT.SUCCESS_OVERWRITE):format(
        mappedAssetsCount or 0, skippedAssetsCount or 0)
    return { success = true, msg = msg }
end

function PB_UserData:toggleAssetFavorite(assetKey)
    if OD_HasValue(self.current.favorites, assetKey) then
        OD_RemoveValue(self.current.favorites, assetKey)
        self:save()
        return false
    else
        table.insert(self.current.favorites, 1, assetKey)
        self:save()
        return true
    end
end

function PB_UserData:addAssetToRecents(assetKey)
    if OD_HasValue(self.current.recents, assetKey) then
        OD_RemoveValue(self.current.recents, assetKey)
    end

    table.insert(self.current.recents, 1, assetKey)

    -- Keep only the most recent items (limit from settings)
    local maxRecents = self.app.settings.current.numberOfRecents or 5
    while #self.current.recents > maxRecents do
        table.remove(self.current.recents)
    end

    self:save()
end

function PB_UserData:addTagToAsset(assetId, tagId, save)
    save = (save == nil) and true or save

    self.current.taggedAssets[assetId] = self.current.taggedAssets[assetId] or {}
    if not OD_HasValue(self.current.taggedAssets[assetId], tagId) then
        table.insert(self.current.taggedAssets[assetId], tagId)
        if save then self:save() end
        return true
    end
    return false
end

function PB_UserData:removeTagFromAsset(assetId, tagId, save)
    save = (save == nil) and true or save

    if self.current.taggedAssets[assetId] then
        if OD_HasValue(self.current.taggedAssets[assetId], tagId) then
            OD_RemoveValue(self.current.taggedAssets[assetId], tagId)
            if not next(self.current.taggedAssets[assetId]) then
                self.current.taggedAssets[assetId] = nil
            end
            if save then self:save() end
            return true
        end
    end
    return false
end

function PB_UserData:toggleTagOpen(tagId, state, persist)
    persist = (persist == nil) and true or persist
    self.current.tagInfo[tagId].open = state
    if persist then
        self:save()
    end
end

function PB_UserData:renameTag(tagId, name, persist)
    persist = (persist == nil) and true or persist
    self.current.tagInfo[tagId].name = name
    if persist then
        self:save()
        -- Notify engine to refresh its runtime data
        self.app.engine:getTags(true)
    end
end

function PB_UserData:deleteTag(tagId, persistAndReload)
    -- Find the tag's siblings to adjust their order
    local tagInfo = self.current.tagInfo[tagId]
    if not tagInfo then return end

    -- Remove from tagged assets first
    for assetId, tagIds in pairs(self.current.taggedAssets) do
        if OD_HasValue(tagIds, tagId) then
            OD_RemoveValue(tagIds, tagId)
            if #tagIds == 0 then
                self.current.taggedAssets[assetId] = nil
            end
        end
    end

    -- Find and delete all descendant tags recursively
    local function deleteDescendants(parentId)
        for id, info in pairs(self.current.tagInfo) do
            if info.parentId == parentId then
                deleteDescendants(id) -- Delete descendants first

                -- Remove descendant tag from all tagged assets
                for assetId, tagIds in pairs(self.current.taggedAssets) do
                    if OD_HasValue(tagIds, id) then
                        OD_RemoveValue(tagIds, id)
                        if #tagIds == 0 then
                            self.current.taggedAssets[assetId] = nil
                        end
                    end
                end

                self.current.tagInfo[id] = nil
            end
        end
    end
    deleteDescendants(tagId)

    -- Adjust sibling order
    for sibId, sibInfo in pairs(self.current.tagInfo) do
        if sibInfo.parentId == tagInfo.parentId and sibInfo.order > tagInfo.order then
            self.current.tagInfo[sibId].order = sibInfo.order - 1
        end
    end

    -- Delete the tag itself
    self.current.tagInfo[tagId] = nil
    if persistAndReload ~= false then
        self:save()
        -- Notify engine to refresh its runtime data
        self.app.engine:getTags(true)
        self.app.engine:tagAssets()
    end
end

function PB_UserData:deleteAllTags()
    self.app.logger:logDebug('-- PB_UserData:deleteAllTags()')

    local tagCount = 0
    for tagId, tag in pairs(self.current.tagInfo) do
        if tag.parentId == TAGS_ROOT_PARENT then
            self:deleteTag(tagId, false)
        end
        tagCount = tagCount + 1
    end

    self:save()

    self.app.engine:getTags(true)
    self.app.engine:tagAssets()

    self.app.flow.filterResults({ clear = true })

    self.app.logger:logInfo('Deleted all ' .. tagCount .. ' tags')
    return tagCount
end

function PB_UserData:createTag(name, parent)
    self.app.logger:logDebug('-- PB_UserData:createTag()')
    self.app.logger:logDebug('Creating tag "' .. name .. '"')

    local parentId = (parent == TAGS_ROOT_PARENT) and TAGS_ROOT_PARENT or parent.id
    local levelCount = 0

    -- Count existing tags at this level
    for id, tagInfo in pairs(self.current.tagInfo) do
        if tagInfo.parentId == parentId then
            levelCount = levelCount + 1
        end
    end

    local newTag = {
        name = name,
        parentId = parentId,
        order = levelCount + 1
    }

    local newId = self.current.tagIdCount + 1
    self.current.tagIdCount = newId
    self.current.tagInfo[newId] = newTag

    self.app.logger:logInfo('Created a new tag \'' ..
        name ..
        '\' with id ' ..
        newId .. (parentId ~= TAGS_ROOT_PARENT and ' (parent Id: ' .. parentId .. ')' or ''))

    self:save()

    -- Notify engine to refresh its runtime data
    self.app.engine:getTags(true)

    -- Return the created tag from engine's processed data
    for _, tag in pairs(self.app.engine.tags) do
        if tag.id == newId then
            return tag
        end
    end
end

-- Preset management functions
function PB_UserData:createPreset(name, filter, word)
    if not name or name == '' then
        self.app.logger:logError('Cannot create preset: name is required')
        return nil
    end

    if not filter then
        self.app.logger:logError('Cannot create preset: filter is required')
        return nil
    end

    if OD_TableLength(OD_TableFilter(self.current.presets, function(k, v)
            return v.word ~= nil and v.word ~= '' and
                v.word:upper() == word:upper()
        end)) > 0 then
        self.app.logger:logError('Cannot create preset: preset with word ' .. word .. ' already exists')
        return nil
    end

    -- Create a deep copy of the filter to store
    local presetFilter = OD_DeepCopy(filter)

    local newId = self.current.presetIdCount + 1
    self.current.presetIdCount = newId

    local preset = {
        id = newId,
        name = name,
        word = word,
        filter = presetFilter,
    }

    self.current.presets[newId] = preset

    self.app.logger:logInfo('Created preset \'' .. name .. '\' with id ' .. newId)

    self:save()

    -- Notify engine to refresh its runtime data
    if self.app.engine then
        self.app.engine:getPresets(true)
    end

    return preset
end

function PB_UserData:deletePreset(presetId)
    if not self.current.presets[presetId] then
        self.app.logger:logError('Cannot delete preset: preset with id ' .. presetId .. ' not found')
        return false
    end

    local presetName = self.current.presets[presetId].name
    self.current.presets[presetId] = nil

    self.app.logger:logInfo('Deleted preset \'' .. presetName .. '\' with id ' .. presetId)

    self:save()

    -- Notify engine to refresh its runtime data
    if self.app.engine then
        self.app.engine:getPresets(true)
    end

    return true
end

function PB_UserData:renamePreset(presetId, newName)
    if not newName or newName == '' then
        self.app.logger:logError('Cannot rename preset: new name is required')
        return false
    end

    if not self.current.presets[presetId] then
        self.app.logger:logError('Cannot rename preset: preset with id ' .. presetId .. ' not found')
        return false
    end

    local oldName = self.current.presets[presetId].name
    self.current.presets[presetId].name = newName

    self.app.logger:logInfo('Renamed preset from \'' .. oldName .. '\' to \'' .. newName .. '\'')

    self:save()

    -- Notify engine to refresh its runtime data
    if self.app.engine then
        self.app.engine:getPresets(true)
    end

    return true
end

function PB_UserData:updatePreset(presetId, name, filter, word)
    if not self.current.presets[presetId] then
        self.app.logger:logError('Cannot update preset: preset with id ' .. presetId .. ' not found')
        return nil
    end

    if not name or name == '' then
        self.app.logger:logError('Cannot update preset: name is required')
        return nil
    end

    if not filter then
        self.app.logger:logError('Cannot update preset: filter is required')
        return nil
    end

    if OD_TableLength(OD_TableFilter(self.current.presets, function(k, v) return (v.id ~= presetId and v.word ~= nil and v.word ~= '' and v.word:upper() == word:upper()) end)) > 0 then
        self.app.logger:logError('Cannot update preset: preset with word ' .. word .. ' already exists')
        return nil
    end

    -- Create a deep copy of the filter to store
    local presetFilter = OD_DeepCopy(filter)

    self.current.presets[presetId].name = name
    self.current.presets[presetId].word = word
    self.current.presets[presetId].filter = presetFilter

    self.app.logger:logInfo('Updated preset \'' .. name .. '\' with id ' .. presetId)

    self:save()

    -- Notify engine to refresh its runtime data
    if self.app.engine then
        self.app.engine:getPresets(true)
    end

    return self.current.presets[presetId]
end

function PB_UserData:getPreset(presetId)
    return self.current.presets[presetId]
end

function PB_UserData:getAllPresets()
    return self.current.presets
end

-- Quick Chain management functions
function PB_UserData:createQuickChain(name, items, word)
    if not name or name == '' then
        self.app.logger:logError('Cannot create quick chain: name is required')
        return nil
    end

    if not items or type(items) ~= 'table' then
        self.app.logger:logError('Cannot create quick chain: items array is required')
        return nil
    end

    -- Check if magic word is already used by another quick chain
    if word and word ~= '' then
        if OD_TableLength(OD_TableFilter(self.current.quickChains, function(k, v)
                return v.word ~= nil and v.word ~= '' and
                    v.word:upper() == word:upper()
            end)) > 0 then
            self.app.logger:logError('Cannot create quick chain: quick chain with magic word "' .. word .. '" already exists')
            return nil
        end
    end

    -- Create a deep copy of the items array to store
    local quickChainItems = OD_DeepCopy(items)

    local newId = self.current.quickChainIdCount + 1
    self.current.quickChainIdCount = newId

    local quickChain = {
        id = newId,
        name = name,
        word = word,
        items = quickChainItems,
    }

    self.current.quickChains[newId] = quickChain

    self.app.logger:logInfo('Created quick chain "' .. name .. '" with id ' .. newId .. 
        (word and (' and magic word "' .. word .. '"') or ''))

    self:save()
    self.app.engine:getQuickChains() -- Notify engine to refresh its runtime data
    
    -- Refresh Quick Chain assets so they appear in the UI immediately
    if self.app.engine then
        self.app.engine:assembleAssets()
    end
    
    return quickChain
end

function PB_UserData:deleteQuickChain(quickChainId)
    if not self.current.quickChains[quickChainId] then
        self.app.logger:logError('Cannot delete quick chain: quick chain with id ' .. quickChainId .. ' not found')
        return false
    end

    local quickChainName = self.current.quickChains[quickChainId].name
    self.current.quickChains[quickChainId] = nil

    self.app.logger:logInfo('Deleted quick chain "' .. quickChainName .. '" with id ' .. quickChainId)

    self:save()
    self.app.engine:getQuickChains() -- Notify engine to refresh its runtime data

    -- Refresh Quick Chain assets so they are removed from the UI immediately
    if self.app.engine then
        self.app.engine:assembleAssets()
    end

    return true
end

function PB_UserData:updateQuickChain(quickChainId, name, items, word)
    if not self.current.quickChains[quickChainId] then
        self.app.logger:logError('Cannot update quick chain: quick chain with id ' .. quickChainId .. ' not found')
        return nil
    end

    if not name or name == '' then
        self.app.logger:logError('Cannot update quick chain: name is required')
        return nil
    end

    if not items or type(items) ~= 'table' then
        self.app.logger:logError('Cannot update quick chain: items array is required')
        return nil
    end

    -- Check if magic word is already used by another quick chain
    if word and word ~= '' then
        if OD_TableLength(OD_TableFilter(self.current.quickChains, function(k, v) 
                return (v.id ~= quickChainId and v.word ~= nil and v.word ~= '' and 
                    v.word:upper() == word:upper()) 
            end)) > 0 then
            self.app.logger:logError('Cannot update quick chain: quick chain with magic word "' .. word .. '" already exists')
            return nil
        end
    end

    -- Create a deep copy of the items array to store
    local quickChainItems = OD_DeepCopy(items)

    self.current.quickChains[quickChainId].name = name
    self.current.quickChains[quickChainId].word = word
    self.current.quickChains[quickChainId].items = quickChainItems

    self.app.logger:logInfo('Updated quick chain "' .. name .. '" with id ' .. quickChainId)

    self:save()
    self.app.engine:getQuickChains() -- Notify engine to refresh its runtime data

    -- Refresh Quick Chain assets so changes appear in the UI immediately
    if self.app.engine then
        self.app.engine:assembleAssets()
    end

    return self.current.quickChains[quickChainId]
end

function PB_UserData:getQuickChain(quickChainId)
    return self.current.quickChains[quickChainId]
end

function PB_UserData:getAllQuickChains()
    return self.current.quickChains
end

function PB_UserData:getQuickChainByWord(word)
    if not word or word == '' then
        return nil
    end

    for _, quickChain in pairs(self.current.quickChains) do
        if quickChain.word and quickChain.word:upper() == word:upper() then
            return quickChain
        end
    end

    return nil
end

-- Resolve Quick Chain items from asset keys to full asset objects
function PB_UserData:resolveQuickChainAssets(quickChainId)
    local quickChain = self:getQuickChain(quickChainId)
    if not quickChain then
        self.app.logger:logError('Cannot resolve Quick Chain assets: Quick Chain with id ' .. quickChainId .. ' not found')
        return nil
    end

    if not self.app.engine then
        self.app.logger:logError('Cannot resolve Quick Chain assets: DataEngine not available')
        return nil
    end

    -- Get all assets for the Quick Chain items
    local resolvedAssets = self.app.engine:getAssetsByKeys(quickChain.items)
    
    if #resolvedAssets ~= #quickChain.items then
        local foundCount = #resolvedAssets
        local totalCount = #quickChain.items
        self.app.logger:logInfo('Quick Chain "' .. quickChain.name .. '": resolved ' .. 
            foundCount .. ' of ' .. totalCount .. ' assets (some assets may no longer be available)')
    end

    return {
        id = quickChain.id,
        name = quickChain.name,
        word = quickChain.word,
        items = quickChain.items, -- Original asset keys
        assets = resolvedAssets   -- Resolved asset objects
    }
end

-- Resolve all Quick Chains with their assets
function PB_UserData:getAllQuickChainsWithAssets()
    local quickChainsWithAssets = {}
    
    for id, _ in pairs(self.current.quickChains) do
        local resolvedQuickChain = self:resolveQuickChainAssets(id)
        if resolvedQuickChain then
            quickChainsWithAssets[id] = resolvedQuickChain
        end
    end
    
    return quickChainsWithAssets
end

-- Quick lookup for resolved Quick Chain by magic word
function PB_UserData:resolveQuickChainByWord(word)
    local quickChain = self:getQuickChainByWord(word)
    if not quickChain then
        return nil
    end
    
    return self:resolveQuickChainAssets(quickChain.id)
end

function PB_UserData:convertFoldersToTags()
    self.app.logger:logDebug('-- PB_UserData:convertFoldersToTags()')

    -- Check if we have FX folders data
    if not self.app.engine or not self.app.engine.fxFolders or not self.app.engine.pluginToFolders then
        self.app.logger:logError('No FX folders data available')
        return { error = true, msg = 'No FX folders data available' }
    end

    local foldersConverted = 0
    local assetsTagged = 0
    local count = 0
    local totalFolders = OD_TableLength(self.app.engine.fxFolders)
    -- Iterate through each category

    self.app.logger:logDebug('Available folders', OD_TableLength(self.app.engine.fxFolders))

    -- Iterate through each folder
    for folderId, folderData in pairs(self.app.engine.fxFolders) do
        count = count + 1
        local msg = (T.PROGRESS.CONVERT_FOLDERS.CONVERTING):format(folderData.name)
        coroutine.yield({
            progress = true,
            msg = msg,
            index = count,
            total = totalFolders
        })


        local folderName = folderData.name
        if not folderName or folderName == '' then
            goto continue_folder
        end

        self.app.logger:logDebug('Processing folder: ' ..
            folderName .. ' with ' .. OD_TableLength(folderData.items or {}) .. ' items') -- Check if tag already exists (case insensitive)
        local existingTagId = nil
        for tagId, tagData in pairs(self.current.tagInfo) do
            if tagData.name:lower() == folderName:lower() and tagData.parentId == TAGS_ROOT_PARENT then
                existingTagId = tagId
                break
            end
        end

        -- Create tag if it doesn't exist
        local targetTagId = existingTagId
        local isNewTag = false
        if not existingTagId then
            targetTagId = self.current.tagIdCount + 1
            self.current.tagIdCount = targetTagId
            self.current.tagInfo[targetTagId] = {
                name = folderName,
                parentId = TAGS_ROOT_PARENT,
                order = targetTagId
            }
            self.app.logger:logDebug('Created tag "' .. folderName .. '" with ID ' .. targetTagId)
            isNewTag = true
            foldersConverted = foldersConverted + 1
        else
            self.app.logger:logDebug('Using existing tag "' .. folderName .. '" with ID ' .. targetTagId)
        end

        -- Get all plugins in this folder and tag them
        local itemsInFolder = 0
        local assetsChecked = 0

        -- Debug: Check what assets we have
        self.app.logger:logDebug('Total engine assets available', #(self.app.engine.assets or {}))
        if self.app.engine.assets and #self.app.engine.assets > 0 then
            local pluginAssets = 0
            local assetTypes = {}
            for _, asset in ipairs(self.app.engine.assets) do
                local assetTypeName = tostring(asset.type or 'nil')
                assetTypes[assetTypeName] = (assetTypes[assetTypeName] or 0) + 1
                if asset.type == ASSET_TYPE.PluginAssetType then
                    pluginAssets = pluginAssets + 1
                end
            end
            self.app.logger:logDebug('Plugin assets found', pluginAssets)
            for typeName, count in pairs(assetTypes) do
                self.app.logger:logDebug('Asset type: ' .. typeName, count)
            end
        end

        for _, asset in ipairs(self.app.engine.assets) do
            if asset.type == ASSET_TYPE.PluginAssetType then
                assetsChecked = assetsChecked + 1
                if asset.isInFolder then
                    if asset:isInFolder(folderId) then
                        -- Add tag to asset (each plugin can only be in one folder)
                        local wasTagAdded = self:addTagToAsset(asset.id, targetTagId, false)
                        if wasTagAdded then
                            assetsTagged = assetsTagged + 1
                            self.app.logger:logDebug('Tagged plugin "' ..
                                (asset.name or 'Unknown') .. '" with folder tag "' .. folderName .. '"')
                        else
                            self.app.logger:logDebug('Plugin "' ..
                                (asset.name or 'Unknown') .. '" already has folder tag "' .. folderName .. '"')
                        end
                        itemsInFolder = itemsInFolder + 1
                    end
                else
                    self.app.logger:logDebug('Asset missing isInFolder method:', asset.name or 'Unknown')
                end
            end
        end

        self.app.logger:logDebug('Checked ' ..
            assetsChecked .. ' plugin assets, found ' .. itemsInFolder .. ' plugins in folder "' .. folderName .. '"')

        ::continue_folder::
    end

    self:save()

    -- Refresh engine tags
    if self.app.engine then
        self.app.engine:getTags(true)
        self.app.engine:assembleAssets()
    end

    -- Trigger a refresh of the search results
    if self.app.flow then
        self.app.flow.filterResults()
    end

    self.app.logger:logInfo(string.format(T.PROGRESS.CONVERT_FOLDERS.SUCCESS, foldersConverted,
        assetsTagged))
    local msg = (T.PROGRESS.CONVERT_FOLDERS.SUCCESS):format(
        foldersConverted or 0, assetsTagged or 0)
    return { success = true, msg = msg }
end

function PB_UserData:convertCategoriesToTags(args)
    self.app.logger:logDebug('-- PB_UserData:convertCategoriesToTags()')

    -- Check if we have FX categories data
    if not self.app.engine or not self.app.engine.fxCategories or not self.app.engine.pluginToCategories then
        self.app.logger:logError('No FX categories data available')
        coroutine.yield { error = true, msg = 'No FX categories data available' }
    end

    local categoriesConverted = 0
    local assetsTagged = 0
    local count = 0
    local totalCategories = OD_TableLength(self.app.engine.fxCategories)
    -- Iterate through each category
    for categoryName, pluginList in pairs(self.app.engine.fxCategories) do
        count = count + 1
        local msg = (T.PROGRESS.CONVERT_CATEGORIES.CONVERTING):format(categoryName)
        coroutine.yield({
            progress = true,
            msg = msg,
            index = count,
            total = totalCategories
        })
        if not categoryName or categoryName == '' then
            goto continue_category
        end

        -- Check if tag already exists (case insensitive)
        local existingTagId = nil
        for tagId, tagData in pairs(self.current.tagInfo) do
            if tagData.name:lower() == categoryName:lower() and tagData.parentId == TAGS_ROOT_PARENT then
                existingTagId = tagId
                break
            end
        end

        -- Create tag if it doesn't exist
        local targetTagId = existingTagId
        if not existingTagId then
            targetTagId = self.current.tagIdCount + 1
            self.current.tagIdCount = targetTagId
            self.current.tagInfo[targetTagId] = {
                name = categoryName,
                parentId = TAGS_ROOT_PARENT,
                order = targetTagId
            }
            self.app.logger:logDebug('Created tag "' .. categoryName .. '" with ID ' .. targetTagId)
            categoriesConverted = categoriesConverted + 1
        else
            self.app.logger:logDebug('Using existing tag "' .. categoryName .. '" with ID ' .. targetTagId)
        end

        -- Get all plugins in this category and tag them
        local itemsInCategory = 0
        local assetsChecked = 0

        for _, asset in ipairs(self.app.engine.assets) do
            if asset.type == ASSET_TYPE.PluginAssetType then
                assetsChecked = assetsChecked + 1
                if asset.isInCategory then
                    if asset:isInCategory(categoryName) then
                        -- Add tag to asset (plugins can be in multiple categories)
                        local wasTagAdded = self:addTagToAsset(asset.id, targetTagId, false)
                        if wasTagAdded then
                            assetsTagged = assetsTagged + 1
                            self.app.logger:logDebug('Tagged plugin "' ..
                                (asset.name or 'Unknown') .. '" with category tag "' .. categoryName .. '"')
                        else
                            self.app.logger:logDebug('Plugin "' ..
                                (asset.name or 'Unknown') .. '" already has category tag "' .. categoryName .. '"')
                        end
                        itemsInCategory = itemsInCategory + 1
                    end
                else
                    self.app.logger:logDebug('Asset missing isInCategory method:', asset.name or 'Unknown')
                end
            end
        end

        self.app.logger:logDebug('Checked ' ..
            assetsChecked ..
            ' plugin assets, found ' .. itemsInCategory .. ' plugins in category "' .. categoryName .. '"')

        ::continue_category::
    end

    self:save()

    -- Refresh engine tags
    if self.app.engine then
        self.app.engine:getTags(true)
        self.app.engine:assembleAssets()
    end


    -- Trigger a refresh of the search results
    if self.app.flow then
        self.app.flow.filterResults()
    end

    self.app.logger:logInfo(string.format(T.PROGRESS.CONVERT_CATEGORIES.SUCCESS, categoriesConverted,
        assetsTagged))

    local msg = (T.PROGRESS.CONVERT_CATEGORIES.SUCCESS):format(
        categoriesConverted or 0, assetsTagged or 0)
    return { success = true, msg = msg }
end

-- * local
