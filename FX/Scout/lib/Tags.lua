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
        local exportAsset = asset
        
        -- For actions, convert command ID to named command ID if possible
        local assetType = tonumber(asset:match("^(%d+)"))
        if assetType == ASSET_TYPE.ActionAssetType then
            local commandId = tonumber(asset:match("^%d+%s+(.+)$"))
            if commandId then
                local namedCommand = r.ReverseNamedCommandLookup(commandId)
                if namedCommand and namedCommand ~= "" then
                    -- Use named command ID (add _ prefix as per REAPER convention)
                    exportAsset = ASSET_TYPE.ActionAssetType .. " _" .. namedCommand
                    self.app.logger:logDebug('Converted action ' .. commandId .. ' to named command _' .. namedCommand)
                else
                    -- Keep numeric ID for native actions
                    self.app.logger:logDebug('Keeping numeric ID for native action', commandId)
                end
            end
        end
        
        -- Sanitize asset ID and write with proper escaping
        local sanitizedAsset = OD_EscapeCSV(exportAsset)
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
    
    -- Check for nil database collections that could cause "attempt to index a nil value" errors
    local collections = {'plugins', 'fxChains', 'trackTemplates', 'tracks', 'actions'}
    for _, collection in ipairs(collections) do
        if not self.app.db[collection] then
            local errorMsg = "self.app.db." .. collection .. " is nil - make sure to call db:init() first"
            self.app.logger:logError(errorMsg)
            return false, errorMsg, {}, 0, 0
        end
    end
    
    local file = io.open(filename, 'r')
    if not file then 
        self.app.logger:logError('Failed to open file for reading', filename)
        return false, {}, 0, 0
    end

    local section = nil
    local importedTagInfo = {}
    local importedTaggedAssets = {}
    local fileVersion = nil

    self.app.logger:logDebug('Parsing tags file...')

    for line in file:lines() do
        if line:match("^%[version%]") then
            section = "version"
        elseif line:match("^%[tagInfo%]") then
            section = "tagInfo"
        elseif line:match("^%[taggedAssets%]") then
            section = "taggedAssets"
        elseif section == "version" and line ~= "" then
            local version = line:match("^fileVersion=(.+)$")
            if version then
                fileVersion = version
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
                    -- Extract basename for matching - different logic for different asset types
                    local imported_basename
                    local assetType = tonumber(asset:match("^(%d+)"))
                    
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
                        -- For actions, extract the command identifier (could be named or numeric)
                        local commandIdentifier = asset:match("^%d+%s+(.+)$")
                        if commandIdentifier and commandIdentifier:match("^_") then
                            -- This is a named command ID, convert to numeric for matching
                            local namedCommand = commandIdentifier:sub(2) -- Remove the _ prefix
                            local numericCommandId = r.NamedCommandLookup(commandIdentifier)
                            if numericCommandId and numericCommandId ~= 0 then
                                imported_basename = tostring(numericCommandId)
                                self.app.logger:logDebug('Converted named command ' .. commandIdentifier .. ' to numeric ID ' .. imported_basename)
                            else
                                self.app.logger:logDebug('Could not convert named command to numeric ID', commandIdentifier)
                                imported_basename = commandIdentifier -- Keep as-is if conversion fails
                            end
                        else
                            -- This is already a numeric command ID
                            imported_basename = commandIdentifier
                        end
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
                            importedTaggedAssets[imported_basename] = {
                                tagIds = tag_ids,
                                originalAssetId = asset
                            }
                        else
                            self.app.logger:logError('No valid tag IDs found in line', line)
                        end
                    else
                        self.app.logger:logError('Could not extract basename from asset', asset)
                    end
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
        
        -- Merge mode: find existing tags with same name and map IDs
        local idMapping = {} -- maps imported ID to existing ID
        local nextNewId = self.current.idCount + 1
        local newTagsCount = 0
        local existingTagsCount = 0
        
        for importedId, importedTag in pairs(importedTagInfo) do
            local existingId = nil
            -- Look for existing tag with same name
            for existingTagId, existingTag in pairs(self.current.tagInfo) do
                if existingTag.name == importedTag.name then
                    existingId = existingTagId
                    break
                end
            end
            
            if existingId then
                -- Tag exists, use existing ID
                idMapping[importedId] = existingId
                existingTagsCount = existingTagsCount + 1
                self.app.logger:logDebug('Tag "' .. importedTag.name .. '" already exists, mapping ' .. importedId .. ' -> ' .. existingId)
            else
                -- New tag, assign new ID
                idMapping[importedId] = nextNewId
                self.current.tagInfo[nextNewId] = {
                    name = importedTag.name,
                    parentId = importedTag.parentId,
                    order = importedTag.order
                }
                newTagsCount = newTagsCount + 1
                self.app.logger:logDebug('Adding new tag "' .. importedTag.name .. '" with ID', nextNewId)
                nextNewId = nextNewId + 1
            end
        end
        
        -- Update idCount
        self.current.idCount = nextNewId - 1
        
        self.app.logger:logDebug('Merge mode: mapped ' .. existingTagsCount .. ' existing tags, ' .. newTagsCount .. ' new tags added')
        
        -- Remap parent IDs using the mapping
        for newId, tag in pairs(self.current.tagInfo) do
            if tag.parentId and idMapping[tag.parentId] then
                tag.parentId = idMapping[tag.parentId]
            end
        end
        
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
    
    for imported_basename, assetData in pairs(importedTaggedAssets) do
        self.app.logger:logDebug('Processing imported asset: basename="' .. imported_basename .. '" originalAssetId="' .. assetData.originalAssetId .. '"')
        
        -- Extract asset type from original asset ID
        local assetType = tonumber(assetData.originalAssetId:match("^(%d+)"))
        if not assetType then
            self.app.logger:logDebug('✗ Could not extract asset type from originalAssetId: "' .. assetData.originalAssetId .. '"')
            goto continue
        end
        
        -- Search through all system assets to find one that matches the basename
        local matchedSystemAssetId = nil
        for _, asset in ipairs(self.app.db.assets) do
            -- Check if this asset is of the same type
            if asset.type == assetType then
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
                    -- For actions, use the numeric command ID directly (system assets already store numeric IDs)
                    systemBasename = asset.id:match("^%d+%s+(.+)$")
                end
                
                -- Check if basenames match
                if systemBasename and systemBasename == imported_basename then
                    matchedSystemAssetId = asset.id
                    break
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
            skippedAssetsCount = skippedAssetsCount + 1
            
            self.app.logger:logDebug('✗ Asset "' .. imported_basename .. '" (type ' .. (assetType or "unknown") .. ') not found in system assets')
            
            -- Log some potential matches for debugging
            local potentialMatches = {}
            for _, asset in ipairs(self.app.db.assets) do
                if asset.type == assetType then
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
