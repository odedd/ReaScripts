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
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 4.vst3"] = { 7, 3 },
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"] = { 1 },
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-C 2.vst3"] = { 2 },
            ["1 /Library/Audio/Plug-Ins/VST3/FabFilter Pro-G.vst3"] = { 5 }
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
        file:write(string.format('%d,%s,%d,%d\n', id, tag.name, tag.parentId or 0, tag.order or 0))
        tagCount = tagCount + 1
    end
    file:write('\n')
    
    self.app.logger:logDebug('Exported tags', tagCount)

    -- Export taggedAssets
    file:write('[taggedAssets]\n')
    local assetCount = 0
    for asset, tags in pairs(self.current.taggedAssets) do
        file:write(string.format('%s:%s\n', asset, table.concat(tags, ',')))
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
        return false 
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
            local id, name, parentId, order = line:match("^(%d+),([^,]+),(%d+),(%d+)")
            if id and name then
                importedTagInfo[tonumber(id)] = {
                    name = name,
                    parentId = tonumber(parentId),
                    order = tonumber(order)
                }
            end
        elseif section == "taggedAssets" and line ~= "" then
            local asset, tags = line:match("^(.-):(.+)$")
            if asset and tags then
                -- Only store basename for matching
                local imported_basename = asset:match("([^/\\]+)$")
                local tag_ids = {}
                for tag_id in tags:gmatch("(%d+)") do
                    table.insert(tag_ids, tonumber(tag_id))
                end
                importedTaggedAssets[imported_basename] = tag_ids
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
        return false, errorMsg
    elseif fileVersion == nil then
        -- No version info found - assume legacy format
        self.app.logger:logWarning('No version information found in tags file. Assuming legacy format.')
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
        for basename, tagIds in pairs(importedTaggedAssets) do
            local remappedTagIds = {}
            for _, tagId in ipairs(tagIds) do
                if idMapping[tagId] then
                    table.insert(remappedTagIds, idMapping[tagId])
                end
            end
            if #remappedTagIds > 0 then
                remappedImportedTaggedAssets[basename] = remappedTagIds
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

    -- Get all plugins in your system using self.app.db.plugins 
    local systemAssets = {}
    self.app.logger:logDebug('Mapping plugins from system database...')
    
    for _, plugin in ipairs(self.app.db.plugins) do
        -- Extract basename from the plugin's full_name (which contains the path)
        local basename = plugin.full_name:match("([^/\\]+)$")
        if basename then
            -- Create the asset ID format: "1 " + plugin.ident (1 is ASSETS.PLUGIN)
            local assetId = "1 " .. plugin.ident
            systemAssets[basename] = assetId
        end
    end
    
    local systemPluginCount = 0
    for _ in pairs(systemAssets) do systemPluginCount = systemPluginCount + 1 end
    self.app.logger:logDebug('Found plugins in system database', systemPluginCount)

    -- Remap imported taggedAssets to your system's asset IDs
    local remappedTaggedAssets = {}
    local mappedAssetsCount = 0
    local skippedAssetsCount = 0
    
    self.app.logger:logDebug('Remapping tagged assets to system plugin IDs...')
    
    for imported_basename, tag_ids in pairs(importedTaggedAssets) do
        local systemAssetId = systemAssets[imported_basename]
        if systemAssetId then
            mappedAssetsCount = mappedAssetsCount + 1
            self.app.logger:logDebug('Mapped plugin "' .. imported_basename .. '" to system asset', systemAssetId)
            
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
                for _, tagId in ipairs(tag_ids) do
                    if not OD_HasValue(combinedTags, tagId) then
                        table.insert(combinedTags, tagId)
                    end
                end
                
                remappedTaggedAssets[systemAssetId] = combinedTags
            else
                -- In replace mode, just use imported tags
                remappedTaggedAssets[systemAssetId] = tag_ids
            end
        else
            skippedAssetsCount = skippedAssetsCount + 1
            self.app.logger:logDebug('Plugin "' .. imported_basename .. '" not found in system - skipping')
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
    self.app.logger:logInfo('Import successful: ' .. mappedAssetsCount .. ' assets mapped, ' .. skippedAssetsCount .. ' assets skipped, total tagged assets: ' .. finalAssetCount)

    return true
end
-- * local
