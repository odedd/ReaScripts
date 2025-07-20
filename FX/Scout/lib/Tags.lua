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
            [ASSETS.PLUGIN .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3"] = { 7, 3 },
            [ASSETS.PLUGIN .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"] = { 1 },
            [ASSETS.PLUGIN .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-C 2.vst3"] = { 2 },
            [ASSETS.PLUGIN .. " /Library/Audio/Plug-Ins/VST3/FabFilter Pro-G.vst3"] = { 5 }
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
                    
                    if assetType == ASSETS.PLUGIN or assetType == ASSETS.FX_CHAIN or assetType == ASSETS.TRACK_TEMPLATE then
                        -- For file-based assets, extract basename from path
                        imported_basename = asset:match("([^/\\]+)$")
                    elseif assetType == ASSETS.TRACK or assetType == ASSETS.ACTION then
                        -- For tracks and actions, use the full identifier minus the asset type prefix
                        imported_basename = asset:match("^%d+%s+(.+)$")
                    else
                        -- Fallback: try to extract basename from path, then full identifier
                        imported_basename = asset:match("([^/\\]+)$") or asset:match("^%d+%s+(.+)$")
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

    -- Get all assets in your system using self.app.db
    local systemAssets = {}
    self.app.logger:logDebug('Mapping assets from system database...')
    
    -- Map plugins
    for _, plugin in ipairs(self.app.db.plugins) do
        local basename = plugin.full_name:match("([^/\\]+)$")
        if basename then
            -- Create the asset ID format: ASSETS.PLUGIN + " " + plugin.ident
            local assetId = ASSETS.PLUGIN .. " " .. plugin.ident
            systemAssets[basename] = assetId
        end
    end
    
    -- Map FX chains
    for _, fxChain in ipairs(self.app.db.fxChains) do
        local basename = fxChain.file
        if basename then
            -- Create the asset ID format: ASSETS.FX_CHAIN + " " + fxChain.load
            local assetId = ASSETS.FX_CHAIN .. " " .. fxChain.load
            systemAssets[basename] = assetId
        end
    end
    
    -- Map track templates
    for _, trackTemplate in ipairs(self.app.db.trackTemplates) do
        local basename = trackTemplate.file
        if basename then
            -- Create the asset ID format: ASSETS.TRACK_TEMPLATE + " " + trackTemplate.load
            local assetId = ASSETS.TRACK_TEMPLATE .. " " .. trackTemplate.load
            systemAssets[basename] = assetId
        end
    end
    
    -- Map tracks
    for _, track in ipairs(self.app.db.tracks) do
        local basename = track.name
        if basename then
            -- Create the asset ID format: ASSETS.TRACK + " " + track.guid
            local assetId = ASSETS.TRACK .. " " .. track.guid
            systemAssets[basename] = assetId
        end
    end
    
    -- Map actions
    for _, action in ipairs(self.app.db.actions) do
        local basename = action.name
        if basename then
            -- Create the asset ID format: ASSETS.ACTION + " " + action.id
            local assetId = ASSETS.ACTION .. " " .. action.id
            systemAssets[basename] = assetId
        end
    end
    
    local systemAssetCount = 0
    for _ in pairs(systemAssets) do systemAssetCount = systemAssetCount + 1 end
    self.app.logger:logDebug('Found total system assets', systemAssetCount)

    -- Remap imported taggedAssets to your system's asset IDs
    local remappedTaggedAssets = {}
    local mappedAssetsCount = 0
    local skippedAssetsCount = 0
    local skippedAssets = {} -- Table to track unimported assets with reasons
    local assetTypeCounts = {
        [ASSETS.PLUGIN] = { mapped = 0, skipped = 0 },
        [ASSETS.FX_CHAIN] = { mapped = 0, skipped = 0 },
        [ASSETS.TRACK_TEMPLATE] = { mapped = 0, skipped = 0 },
        [ASSETS.TRACK] = { mapped = 0, skipped = 0 },
        [ASSETS.ACTION] = { mapped = 0, skipped = 0 }
    }
    
    self.app.logger:logDebug('Remapping tagged assets to system asset IDs...')
    
    for imported_basename, assetData in pairs(importedTaggedAssets) do
        local systemAssetId = systemAssets[imported_basename]
        if systemAssetId then
            mappedAssetsCount = mappedAssetsCount + 1
            
            -- Determine asset type for logging
            local assetType = tonumber(systemAssetId:match("^(%d+)"))
            if assetType and assetTypeCounts[assetType] then
                assetTypeCounts[assetType].mapped = assetTypeCounts[assetType].mapped + 1
            end
            
            self.app.logger:logDebug('Mapped asset "' .. imported_basename .. '" to system asset', systemAssetId)
            
            if mergeMode then
                -- In merge mode, combine with existing tags for this asset
                local existingTags = self.current.taggedAssets[systemAssetId] or {}
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
                
                remappedTaggedAssets[systemAssetId] = combinedTags
            else
                -- In replace mode, just use imported tags
                remappedTaggedAssets[systemAssetId] = assetData.tagIds
            end
        else
            skippedAssetsCount = skippedAssetsCount + 1
            
            -- Try to determine what type of asset this might be based on the basename
            -- This is for better logging of what was skipped
            local assetTypeGuess = "unknown"
            local skipReason = IMPORT_SKIP_REASON.ASSET_NOT_FOUND
            
            if imported_basename:match("%.vst3?$") or imported_basename:match("%.dll$") or imported_basename:match("%.component$") then
                assetTypeGuess = "plugin"
                assetTypeCounts[ASSETS.PLUGIN].skipped = assetTypeCounts[ASSETS.PLUGIN].skipped + 1
            elseif imported_basename:match("%.rfxchain$") then
                assetTypeGuess = "FX chain"
                assetTypeCounts[ASSETS.FX_CHAIN].skipped = assetTypeCounts[ASSETS.FX_CHAIN].skipped + 1
            elseif imported_basename:match("%.RTrackTemplate$") then
                assetTypeGuess = "track template"
                assetTypeCounts[ASSETS.TRACK_TEMPLATE].skipped = assetTypeCounts[ASSETS.TRACK_TEMPLATE].skipped + 1
            else
                -- Could be track or action - harder to determine from basename alone
                assetTypeGuess = "track/action"
            end
            
            -- Record the skipped asset with its reason
            table.insert(skippedAssets, {
                basename = imported_basename,
                originalAssetId = assetData.originalAssetId,  -- Store the original asset ID from import
                reason = skipReason,
                assetTypeGuess = assetTypeGuess
            })
            
            self.app.logger:logDebug('Asset "' .. imported_basename .. '" (' .. assetTypeGuess .. ') not found in system - skipping')
        end
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
            if assetType == ASSETS.PLUGIN then typeName = "plugins"
            elseif assetType == ASSETS.FX_CHAIN then typeName = "FX chains"
            elseif assetType == ASSETS.TRACK_TEMPLATE then typeName = "track templates"
            elseif assetType == ASSETS.TRACK then typeName = "tracks"
            elseif assetType == ASSETS.ACTION then typeName = "actions"
            end
            
            if counts.mapped > 0 then
                self.app.logger:logDebug('Mapped ' .. typeName, counts.mapped)
            end
            if counts.skipped > 0 then
                self.app.logger:logDebug('Skipped ' .. typeName, counts.skipped)
            end
        end
    end

    return true, skippedAssets, mappedAssetsCount, skippedAssetsCount
end
-- * local
