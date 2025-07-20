-- @noindex

PB_Tags = OD_Settings:new({
    default = {
        -- Defineable in GUI
        favorites = {},
        tagInfo = {},
        taggedAssets = {},
        idCount = 7,
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

function PB_Tags:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Version and compatibility constants
local TAGS_FILE_VERSION = "1.0"
local COMPATIBLE_VERSIONS = {
    ["1.0"] = true,  -- Current version
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

function PB_Tags:getFileVersion()
    return TAGS_FILE_VERSION
end

function PB_Tags:isVersionCompatible(version)
    return isVersionCompatible(version)
end

function PB_Tags:export(filename)
    -- Export tags and taggedAssets to a file
    self.app.logger:logDebug('-- PB_Tags:export() to', filename)
    
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

    file:close()
    
    self.app.logger:logInfo('Successfully exported ' .. tagCount .. ' tags and ' .. assetCount .. ' tagged assets to ' .. filename)
    
    return true
end

function PB_Tags:import(filename, mergeMode)
    -- mergeMode: true = merge with existing tags, false = replace all tags (default: false)
    mergeMode = mergeMode or false
    
    self.app.logger:logDebug('-- PB_Tags:import() from ' .. filename .. ' mergeMode: ' .. tostring(mergeMode))
    
    -- Check for AssetTypeManager that could cause "attempt to index a nil value" errors
    if not self.app.db.assetTypeManager then
        local errorMsg = "self.app.db.assetTypeManager is nil - make sure to call db:init() first"
        self.app.logger:logError(errorMsg)
        return false, errorMsg, {}, 0, 0
    end
    
    local file = io.open(filename, 'r')
    if not file then 
        self.app.logger:logError('Failed to open file for reading', filename)
        return false, {}, 0, 0
    end

    local section = nil
    local importedTagInfo = {}
    local importedTaggedAssets = {}
    local importedAssetTypes = {} -- Map of imported asset type ID -> class name
    local assetTypeMapping = {} -- Map of imported asset type ID -> current system asset type ID
    local unmappedAssetTypes = {} -- Track asset types that couldn't be mapped
    local fileVersion = nil

    self.app.logger:logDebug('Parsing tags file...')

    for line in file:lines() do
        if line:match("^%[version%]") then
            section = "version"
        elseif line:match("^%[assetTypes%]") then
            section = "assetTypes"
        elseif line:match("^%[tagInfo%]") then
            section = "tagInfo"
        elseif line:match("^%[taggedAssets%]") then
            section = "taggedAssets"
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
                        self.app.logger:logDebug('Asset type mapping', className .. ': ' .. importedId .. ' -> ' .. currentSystemId)
                    else
                        -- Track unmapped asset types for reporting
                        table.insert(unmappedAssetTypes, {
                            importedId = tonumber(importedId),
                            className = className
                        })
                        self.app.logger:logError('Asset type not found in current system', className .. ' (imported ID: ' .. importedId .. ')')
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
                        name = name,  -- Already unescaped by OD_ParseCSVLine
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
                            self.app.logger:logDebug('Skipping asset with unmapped asset type', className .. ' (ID: ' .. importedAssetTypeId .. '): ' .. asset)
                        else
                            self.app.logger:logDebug('Skipping asset with unknown asset type ID', importedAssetTypeId .. ': ' .. asset)
                        end
                        goto continue_asset_parsing
                    end
                    
                    -- Extract basename for matching - different logic for different asset types
                    local imported_basename
                    local assetType = mappedAssetTypeId  -- Use mapped asset type for processing
                    
                    if assetType == ASSET_TYPE.PluginAssetType or assetType == ASSET_TYPE.FXChainAssetType or assetType == ASSET_TYPE.TrackTemplateAssetType then
                        -- For file-based assets, extract basename from path
                        imported_basename = asset:match("([^/\\]+)$")
                        -- For assets with <numbers (like WaveShell), remove the <numbers part
                        if imported_basename and imported_basename:find("<") then
                            imported_basename = imported_basename:match("^(.+)<")
                        end
                    elseif assetType == ASSET_TYPE.TrackAssetType then
                        -- For tracks, use the full identifier minus the asset type prefix
                        imported_basename = asset:match("^%d+%s+(.+)$")
                    elseif assetType == ASSET_TYPE.ActionAssetType then
                        -- For actions, use the command identifier directly (now handles named/numeric internally)
                        imported_basename = asset:match("^%d+%s+(.+)$")
                    else
                        -- Fallback: try to extract basename from path, then full identifier
                        imported_basename = asset:match("([^/\\]+)$") or asset:match("^%d+%s+(.+)$")
                        -- For assets with <numbers (like WaveShell), remove the <numbers part
                        if imported_basename and imported_basename:find("<") then
                            imported_basename = imported_basename:match("^(.+)<")
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
        end
    end
    file:close()

    local importedTagCount = 0
    for _ in pairs(importedTagInfo) do importedTagCount = importedTagCount + 1 end
    local importedAssetCount = 0
    for _ in pairs(importedTaggedAssets) do importedAssetCount = importedAssetCount + 1 end
    self.app.logger:logDebug('Parsed ' .. importedTagCount .. ' tags and ' .. importedAssetCount .. ' tagged assets from file')
    if fileVersion then
        self.app.logger:logDebug('File version', fileVersion)
    end
    
    -- Report unmapped asset types
    if #unmappedAssetTypes > 0 then
        self.app.logger:logInfo('Found ' .. #unmappedAssetTypes .. ' unmapped asset types in imported file:')
        for _, unmappedType in ipairs(unmappedAssetTypes) do
            self.app.logger:logInfo('  ' .. unmappedType.className .. ' (imported ID: ' .. unmappedType.importedId .. ') - not available in current system')
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
        return false, errorMsg, {}, 0, 0
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
        local idMapping = {} -- maps imported ID to existing ID
        local nextNewIdRef = {self.current.idCount + 1} -- Use table for reference
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
                self.app.logger:logDebug('Tag "' .. importedTag.name .. '" at path "' .. pathStr .. '" already exists, mapping ' .. importedId .. ' -> ' .. existingId)
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
                self.app.logger:logDebug('Adding new tag "' .. importedTag.name .. '" at path "' .. pathStr .. '" with ID', nextNewIdRef[1])
                nextNewIdRef[1] = nextNewIdRef[1] + 1
            end
        end
        
        -- Update idCount
        self.current.idCount = nextNewIdRef[1] - 1
        
        self.app.logger:logDebug('Merge mode: mapped ' .. existingTagsCount .. ' existing tags, ' .. newTagsCount .. ' new tags added')
        
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
        
        -- Update idCount to be higher than any imported ID
        local maxId = 0
        for id, _ in pairs(importedTagInfo) do
            if id > maxId then maxId = id end
        end
        self.current.idCount = maxId
        
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
            local targetAssetType = self.app.db.assetTypeManager:getAssetTypeById(assetType)
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
    
    for imported_basename, assetData in pairs(importedTaggedAssets) do
        self.app.logger:logDebug('Processing imported asset: basename="' .. imported_basename .. '" originalAssetId="' .. assetData.originalAssetId .. '"')
        
        -- Use mapped asset type if available, fallback to extracted from original
        local assetType = assetData.mappedAssetType or tonumber(assetData.originalAssetId:match("^(%d+)"))
        if not assetType then
            self.app.logger:logDebug('✗ Could not determine asset type from: "' .. assetData.originalAssetId .. '"')
            goto continue
        end
        
        if assetData.mappedAssetType then
            self.app.logger:logDebug('Using mapped asset type', assetType .. ' for ' .. imported_basename)
        end
        
        -- Search through all system assets to find one that matches the basename
        local matchedSystemAssetId = nil
        
        -- Get cached asset type data
        local cachedAssetTypeData = getAssetTypeData(assetType)
        if cachedAssetTypeData then
            -- Search through the asset data for a matching basename
            for _, data in ipairs(cachedAssetTypeData.data) do
                local asset = cachedAssetTypeData.assetType:assembleAsset(data)
                if asset then
                    -- Extract basename from the system asset ID
                    local systemBasename = nil
                    if assetType == ASSET_TYPE.PluginAssetType or assetType == ASSET_TYPE.FXChainAssetType or assetType == ASSET_TYPE.TrackTemplateAssetType then
                        -- For file-based assets, extract basename from path
                        systemBasename = asset.id:match("([^/\\]+)$")
                        -- For assets with <numbers (like WaveShell), remove the <numbers part
                        if systemBasename and systemBasename:find("<") then
                            systemBasename = systemBasename:match("^(.+)<")
                        end
                    elseif assetType == ASSET_TYPE.TrackAssetType then
                        -- For tracks, use the full identifier minus the asset type prefix
                        systemBasename = asset.id:match("^%d+%s+(.+)$")
                    elseif assetType == ASSET_TYPE.ActionAssetType then
                        -- For actions, extract the command identifier (handles both named and numeric)
                        systemBasename = asset.id:match("^%d+%s+(.+)$")
                    end
                    
                    -- Check if basenames match
                    if systemBasename and systemBasename == imported_basename then
                        matchedSystemAssetId = asset.id
                        break
                    end
                end
            end
        end
        
        if matchedSystemAssetId then
            mappedAssetsCount = mappedAssetsCount + 1
            
            -- Update type counts
            if assetTypeCounts[assetType] then
                assetTypeCounts[assetType].mapped = assetTypeCounts[assetType].mapped + 1
            end
            
            self.app.logger:logDebug('✓ Mapped asset "' .. imported_basename .. '" to system asset "' .. matchedSystemAssetId .. '"')
            
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
            local cachedAssetTypeData = getAssetTypeData(assetType)
            local shouldImportUnmapped = cachedAssetTypeData and not cachedAssetTypeData.assetType.requiresMappingOnImport
            
            if shouldImportUnmapped then
                -- Import asset even without mapping (e.g., for tracks that may be created later)
                mappedAssetsCount = mappedAssetsCount + 1
                
                -- Update type counts
                if assetTypeCounts[assetType] then
                    assetTypeCounts[assetType].mapped = assetTypeCounts[assetType].mapped + 1
                end
                
                -- Use the remapped asset ID from the import data
                local unmappedAssetId = assetData.remappedAssetId or assetData.originalAssetId
                self.app.logger:logDebug('✓ Imported unmapped asset "' .. imported_basename .. '" as "' .. unmappedAssetId .. '" (will apply when asset becomes available)')
                
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
                
                self.app.logger:logDebug('✗ Asset "' .. imported_basename .. '" (type ' .. (assetType or "unknown") .. ') not found in system assets')
                
                -- Log some potential matches for debugging
                local potentialMatches = {}
                if cachedAssetTypeData then
                    for _, data in ipairs(cachedAssetTypeData.data) do
                        local asset = cachedAssetTypeData.assetType:assembleAsset(data)
                        if asset then
                            local systemBasename = nil
                            if assetType == ASSET_TYPE.PluginAssetType or assetType == ASSET_TYPE.FXChainAssetType or assetType == ASSET_TYPE.TrackTemplateAssetType then
                                systemBasename = asset.id:match("([^/\\]+)$")
                                -- For assets with <numbers (like WaveShell), remove the <numbers part
                                if systemBasename and systemBasename:find("<") then
                                    systemBasename = systemBasename:match("^(.+)<")
                                end
                            elseif assetType == ASSET_TYPE.TrackAssetType then
                                systemBasename = asset.id:match("^%d+%s+(.+)$")
                            elseif assetType == ASSET_TYPE.ActionAssetType then
                                systemBasename = asset.id:match("^%d+%s+(.+)$")
                            end
                            
                            if systemBasename and (systemBasename:lower():find(imported_basename:lower(), 1, true) or 
                               imported_basename:lower():find(systemBasename:lower(), 1, true)) then
                                table.insert(potentialMatches, systemBasename)
                                if #potentialMatches >= 3 then break end -- Limit to 3 matches
                            end
                        end
                    end
                end
                
                if #potentialMatches > 0 then
                    self.app.logger:logDebug('  Potential matches found: ' .. table.concat(potentialMatches, ', '))
                else
                    self.app.logger:logDebug('  No similar basenames found in system assets for this type')
                end
                
                -- Determine asset type name for logging
                local assetTypeGuess = "unknown"
                if assetType == ASSET_TYPE.PluginAssetType then
                    assetTypeGuess = "plugin"
                    assetTypeCounts[ASSET_TYPE.PluginAssetType].skipped = assetTypeCounts[ASSET_TYPE.PluginAssetType].skipped + 1
                elseif assetType == ASSET_TYPE.FXChainAssetType then
                    assetTypeGuess = "FX chain"
                    assetTypeCounts[ASSET_TYPE.FXChainAssetType].skipped = assetTypeCounts[ASSET_TYPE.FXChainAssetType].skipped + 1
                elseif assetType == ASSET_TYPE.TrackTemplateAssetType then
                    assetTypeGuess = "track template"
                    assetTypeCounts[ASSET_TYPE.TrackTemplateAssetType].skipped = assetTypeCounts[ASSET_TYPE.TrackTemplateAssetType].skipped + 1
                elseif assetType == ASSET_TYPE.TrackAssetType then
                    assetTypeGuess = "track"
                    assetTypeCounts[ASSET_TYPE.TrackAssetType].skipped = assetTypeCounts[ASSET_TYPE.TrackAssetType].skipped + 1
                elseif assetType == ASSET_TYPE.ActionAssetType then
                    assetTypeGuess = "action"
                    assetTypeCounts[ASSET_TYPE.ActionAssetType].skipped = assetTypeCounts[ASSET_TYPE.ActionAssetType].skipped + 1
                end
                
                -- Record the skipped asset with its reason
                table.insert(skippedAssets, {
                    basename = imported_basename,
                    originalAssetId = assetData.originalAssetId,
                    reason = IMPORT_SKIP_REASON.ASSET_NOT_FOUND,
                    assetTypeGuess = assetTypeGuess
                })
            end
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
    self.app.logger:logInfo('Import successful: ' .. mappedAssetsCount .. ' assets mapped, ' .. skippedAssetsCount .. ' assets skipped, total tagged assets: ' .. finalAssetCount)
    
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
            local typeName = "unknown"
            if assetType == ASSET_TYPE.PluginAssetType then typeName = "plugins"
            elseif assetType == ASSET_TYPE.FXChainAssetType then typeName = "FX chains"
            elseif assetType == ASSET_TYPE.TrackTemplateAssetType then typeName = "track templates"
            elseif assetType == ASSET_TYPE.TrackAssetType then typeName = "tracks"
            elseif assetType == ASSET_TYPE.ActionAssetType then typeName = "actions"
            end
            
            if counts.mapped > 0 then
                self.app.logger:logDebug('Mapped ' .. typeName, counts.mapped)
            end
            if counts.skipped > 0 then
                self.app.logger:logDebug('Skipped ' .. typeName, counts.skipped)
            end
        end
    end

    self:save()
    self.app.db:getTags()
    self.app.db:assembleAssets()
    return true, skippedAssets, mappedAssetsCount, skippedAssetsCount
end
-- * local
