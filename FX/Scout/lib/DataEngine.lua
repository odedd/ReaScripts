-- @noindex

PB_DataEngine = {
    tags = {},
    setUndoPoint = function(self, name, type, trackparm)
        type = type or -1
        trackparm = trackparm or -1
        if not self.surpressUndo then
            r.Undo_OnStateChangeEx2(0, name, type, trackparm)
        end
    end,
    beginUndoBlock = function(self)
        if not self.surpressUndo then
            r.Undo_BeginBlock()
        end
    end,
    endUndoBlock = function(self, name, type)
        type = type or -1
        if not self.surpressUndo then
            r.Undo_EndBlock(name, type)
        end
    end,
    validateFilter = function(self, filter)
        self.app.logger:logDebug('-- PB_DataEngine.validateFilter()')
        
        local validatedFilter = OD_DeepCopy(filter)
        local hasIssues = false
        
        -- Validate FX-related filters
        if validatedFilter.fxFolderId and (not self.fxFolders or not self.fxFolders[validatedFilter.fxFolderId]) then
            self.app.logger:logError('FX Folder ID ' .. tostring(validatedFilter.fxFolderId) .. ' does not exist, ignoring filter')
            validatedFilter.fxFolderId = nil
            hasIssues = true
        end
        
        if validatedFilter.fxCategory and (not self.fxCategories or not self.fxCategories[validatedFilter.fxCategory]) then
            self.app.logger:logError('FX Category "' .. tostring(validatedFilter.fxCategory) .. '" does not exist, ignoring filter')
            validatedFilter.fxCategory = nil
            hasIssues = true
        end
        
        if validatedFilter.fxDeveloper and (not self.fxDevelopers or not self.fxDevelopers[validatedFilter.fxDeveloper]) then
            self.app.logger:logError('Developer "' .. tostring(validatedFilter.fxDeveloper) .. '" does not exist, ignoring filter')
            validatedFilter.fxDeveloper = nil
            hasIssues = true
        end
        
        -- Validate tag filters
        if validatedFilter.tags then
            local validTags = {}
            for tagId, positive in pairs(validatedFilter.tags) do
                if self.tags and self.tags[tagId] then
                    validTags[tagId] = positive
                else
                    self.app.logger:logError('Tag ID ' .. tostring(tagId) .. ' does not exist, ignoring tag filter')
                    hasIssues = true
                end
            end
            validatedFilter.tags = validTags
        end
        
        return validatedFilter, hasIssues
    end,
    refreshTracks = function(self)
        -- Helper function to refresh tracks using the modular system
        if self.assetTypeManager then
            local trackAssetType = self.assetTypeManager:getAssetTypeById(ASSET_TYPE.TrackAssetType)
            if trackAssetType then
                self.tracks = trackAssetType:getData()
                self.app.logger:logDebug('Refreshed tracks using modular system')
            else
                self.app.logger:logError('Could not find track asset type')
                self.tracks = {}
            end
        else
            self.app.logger:logError('AssetTypeManager not available')
            self.tracks = {}
        end
    end,
    lastGuids = {}, -- use to check if a track has been removed or added
    init = function(self, app)
        self.app.logger:logDebug('-- PB_DataEngine.init()')
        self.masterTrack = reaper.GetMasterTrack(0)

        -- Initialize fields that will be populated by asset types
        self.fxDevelopers = {}
        self.pluginToCategories = {}
        self.pluginToFolders = {}

        -- Functions still needed by other parts of the system
        self:getFXFolders()
        self:getFXCategories()

        -- Load and initialize AssetTypeManager (after FX data is ready)
        dofile(debug.getinfo(1, "S").source:match("@(.*/)") .. "AssetTypeManager.lua")
        self.assetTypeManager = AssetTypeManager:new(self)

        -- Populate the dynamic filter menu
        FILTER_MENU[FILTER_TYPES.TYPE].items = self.assetTypeManager:buildFilterMenu()

        -- if self.app.logger.profile then Profile.start() end

        self:getTags()
        self:getPresets()

        -- Use the new modular assembleAssets
        self:assembleAssets()
        self:updateDevelopersFilterMenu()
        self:updatePresetsFilterMenu()
        self:assembleFilterAssets()
        -- if self.app.logger.profile then
        --     Profile.stop()
        --     r.ShowConsoleMsg(Profile.report(10))
        -- end
    end,
    sync = function(self, refresh) -- not sure this is needed
        self.app.logger:logDebug('-- PB_DataEngine.sync()')
        self.refresh = refresh or false
        self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force full sync
        if self.current_project ~= self.previous_project then
            self.app.logger:logDebug('Project changed, forcing full sync')
            self:refreshTracks()
            self.previous_project = self.current_project
            self.refresh = true
        end

        if self.refresh then
            self.app.logger:logDebug('Refreshing to search page')
            self.app.flow.setPage(APP_PAGE.SEARCH)
        end
    end
}

-- Cache management
PB_DataEngine.invalidateGroupPriorityCache = function(self)
    self._groupPriorityCache = nil
    self._lastGroupOrder = nil
    self.app.logger:logDebug('Group priority cache invalidated')
end

-- get project tracks into self.tracks, keeping the track's GUID, name and color, and wheather it has receives or not

PB_DataEngine.getSelectedTracks = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.getSelectedTracks()')
    self:refreshTracks()
    local numTracks = r.CountSelectedTracks(0);
    local tracks = {};
    self.app.logger:logDebug('Found selected tracks', numTracks)
    for i = 0, numTracks - 1 do
        local track = r.GetSelectedTrack(0, i)

        for i, trk in ipairs(self.tracks) do
            if track == trk.object then
                table.insert(tracks, trk)
            end
        end
    end
    return tracks;
end

PB_DataEngine._getTrack = function(self, track)
    self.app.logger:logDebug('-- PB_DataEngine._getTrack()')
    for i, trk in ipairs(self.tracks) do
        if track == trk.object then
            return trk
        end
    end
    self.app.logger:logDebug('Track not found in database')
    return nil
end
PB_DataEngine.getFXFolders = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.getFXFolders()')
    self.fxFolders = {}
    self.pluginToFolders = {}

    local content = OD_GetContent(r.GetResourcePath() .. "/" .. "reaper-fxfolders.ini"):gsub("\r\n", "\n"):gsub("\r",
        "\n")

    -- Parse folder names
    local foldersSection = content:match("%[Folders%](.-)\n%[")
    if not foldersSection then
        foldersSection = content:match("%[Folders%](.*)")
    end

    local folderCount = 0
    if foldersSection then
        local parsedIds = {}
        for line in foldersSection:gmatch("[^\n]+") do
            local id, parsedId = line:match("Id(%d+)=(.+)")
            if id and parsedId then
                parsedIds[id] = parsedId
            end
        end
        for line in foldersSection:gmatch("[^\n]+") do
            local id, name = line:match("Name(%d+)=(.+)")
            if id and name then
                self.fxFolders[parsedIds[id]] = { order = id, name = name }
                folderCount = folderCount + 1
                self.app.logger:logDebug('Found folder "' .. name .. '" (id: ' .. parsedIds[id] .. ')')
            end
        end
        self.app.logger:logDebug('Found ' .. folderCount .. ' folder IDs')
    else
        self.app.logger:logError('Could not parse [Folders] section')
    end

    for id, folder in pairs(self.fxFolders) do
        local pattern = "%[Folder" .. id .. "%](.-)\n%["
        local section = content:match(pattern)
        if not section then
            section = content:match("%[Folder" .. id .. "%](.*)")
        end
        if section then
            local items = {}
            for line in section:gmatch("[^\n]+") do
                local itemId, itemName = line:match("Item(%d+)=(.+)")
                if itemName and itemId then
                    items[itemId] = { order = itemId, name = itemName }
                end
            end
            for line in section:gmatch("[^\n]+") do
                local itemId, type = line:match("Type(%d+)=(.+)")
                if type and itemId and items[itemId] then
                    items[itemId].type = type
                    self.app.logger:logDebug('Added ' ..
                        items[itemId].name .. ' to ' .. folder.name .. ' (type ' .. type .. ')')
                end
            end

            self.fxFolders[id].items = items

            -- Build reverse lookup for pluginToFolders
            for _, item in pairs(items) do
                if not self.pluginToFolders[item.name] then
                    self.pluginToFolders[item.name] = {}
                end
                table.insert(self.pluginToFolders[item.name], id)
            end
        end
    end
    self.app.logger:logInfo('Found ' .. folderCount .. ' FX folders')

    -- Update FILTER_MENU
    FILTER_MENU[FILTER_TYPES.FOLDER].items = {}
    for id, fxFolder in OD_PairsByOrder(self.fxFolders) do
        FILTER_MENU[FILTER_TYPES.FOLDER].items[fxFolder.name] = {
            order = tonumber(fxFolder.order),
            query = { fxFolderId = id }
        }
    end
end

PB_DataEngine.getFXCategories = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.getFXCategories()')
    self.fxCategories = {}
    self.pluginToCategories = {}

    local content = OD_GetContent(r.GetResourcePath() .. "/" .. "reaper-fxtags.ini")
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Extract only [category] section up to next section or end
    local categorySection = content:match("%[category%](.-)\n%[")
    if not categorySection then
        categorySection = content:match("%[category%](.*)")
    end

    if categorySection then
        local categoryCount = 0
        local pluginCount = 0
        for line in categorySection:gmatch("[^\n]+") do
            local plugin, categoriesStr = line:match("([^=]+)=(.+)")
            if plugin and categoriesStr then
                pluginCount = pluginCount + 1
                for category in categoriesStr:gmatch("[^|]+") do
                    category = category:gsub("^%s+", ""):gsub("%s+$", "")
                    if not self.fxCategories[category] then
                        categoryCount = categoryCount + 1
                        self.fxCategories[category] = {}
                    end
                    table.insert(self.fxCategories[category], plugin)

                    -- Build reverse lookup table
                    if not self.pluginToCategories[plugin] then
                        self.pluginToCategories[plugin] = {}
                    end
                    table.insert(self.pluginToCategories[plugin], category)

                    self.app.logger:logDebug('Added plugin "' .. plugin .. '" to category "' .. category .. '"')
                end
            end
        end
        self.app.logger:logInfo('Parsed ' ..
            pluginCount .. ' plugins into ' .. categoryCount .. ' categories')
    else
        self.app.logger:logError('Could not find [category] section in reaper-fxtags.ini')
    end

    -- Update FILTER_MENU
    FILTER_MENU[FILTER_TYPES.CATEGORY].items = {}

    local categoryNames = {}
    for name in pairs(self.fxCategories) do
        table.insert(categoryNames, name)
    end
    table.sort(categoryNames)

    for index, categoryName in ipairs(categoryNames) do
        FILTER_MENU[FILTER_TYPES.CATEGORY].items[categoryName] = {
            order = index,
            query = { fxCategory = categoryName }
        }
    end
end

PB_DataEngine.updateDevelopersFilterMenu = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.updateDevelopersFilterMenu()')
    FILTER_MENU[FILTER_TYPES.DEVELOPER].items = {}

    local developerNames = {}
    for s, c in pairs(self.fxDevelopers) do
        table.insert(developerNames, s)
    end
    table.sort(developerNames)

    for index, developerName in ipairs(developerNames) do
        FILTER_MENU[FILTER_TYPES.DEVELOPER].items[developerName] = {
            order = index,
            query = { fxDeveloper = developerName }
        }
    end

    self.app.logger:logDebug('Updated developers filter menu with developers', #developerNames)
end

PB_DataEngine.updatePresetsFilterMenu = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.updatePresetsFilterMenu()')
    FILTER_MENU[FILTER_TYPES.PRESET].items = {}

    local presetNames = {}
    for id, preset in pairs(self.presets) do
        table.insert(presetNames, { id = id, name = preset.name, preset = preset, word = preset.word })
    end
    table.sort(presetNames, function(a, b) return a.name < b.name end)

    for index, presetData in ipairs(presetNames) do
        FILTER_MENU[FILTER_TYPES.PRESET].items[presetData.name] = {
            order = index,
            query = { preset = presetData.id } -- Store preset ID in query
        }
    end

    self.app.logger:logDebug('Updated presets filter menu with presets', #presetNames)
end



-- TAGS AND FAVORITES
PB_DataEngine.getTags = function(self, reassembleTagFilterAssets)
    self.tags = OD_DeepCopy(self.app.userdata.current.tagInfo)
    local function hasCycle(tagId, visited)
        visited = visited or {}
        if visited[tagId] then return true end
        visited[tagId] = true
        local parentId = self.tags[tagId] and self.tags[tagId].parentId
        if parentId and parentId ~= TAGS_ROOT_PARENT and self.tags[parentId] then
            return hasCycle(parentId, visited)
        end
        return false
    end

    for id, tagInfo in pairs(self.app.userdata.current.tagInfo) do
        -- Remove illegal parentId if it would cause a stack overflow (cycle)
        if tagInfo.parentId and tagInfo.parentId ~= TAGS_ROOT_PARENT and (tagInfo.parentId == id or hasCycle(id)) then
            self.app.logger:logError('Cycle detected for tag "' ..
                (self.tags[id] and self.tags[id].name or tostring(id)) .. '", removing parentId')
            self.tags[id].parentId = TAGS_ROOT_PARENT
            tagInfo.parentId = TAGS_ROOT_PARENT
        end

        if tagInfo.parentId and tagInfo.parentId ~= TAGS_ROOT_PARENT and self.tags[tagInfo.parentId] and tagInfo.parentId ~= id then
            self.tags[id].parent = self.tags[tagInfo.parentId]
            self.app.logger:logDebug('Added "' ..
                self.tags[id].name .. '" (parent: "' .. self.tags[id].parent.name .. '")')
        elseif tagInfo.parentId and tagInfo.parentId == id then
            self.app.logger:logError('Illegal parent ID for tag "' .. self.tags[id].name .. '" (parent=own ID)')
        elseif tagInfo.parentId and tagInfo.parentId ~= TAGS_ROOT_PARENT then
            self.app.logger:logError('Illegal parent ID for tag "' .. self.tags[id].name .. '"')
        else
            self.app.logger:logDebug('Added "' .. self.tags[id].name .. '"')
        end
        self.tags[id].id = id
        self.tags[id].app = self.app
        self.tags[id].allTags = self.tags
        self.tags[id].engine = self

        self.tags[id].toggleOpen = function(self, state, persist)
            self.open = state
            self.app.userdata:toggleTagOpen(self.id, state, persist)
        end
        self.tags[id].rename = function(self, name, persist)
            self.name = name
            self.app.userdata:renameTag(self.id, name, persist)
        end
        self.tags[id].delete = function(self, persistAndReload)
            local assetsToRemoveTag = self.engine:assetsWithTag(self)
            if self.app.temp.filter.tags then
                self.app.flow.filterResults({ removeTags = { self.id } })
            end
            for _, asset in pairs(assetsToRemoveTag) do
                asset:removeTag(self, false)
            end
            -- Let UserData handle the actual deletion logic
            self.app.userdata:deleteTag(self.id, persistAndReload)
        end

        self.tags[id].addDescendants = function(self)
            if self.descendants == nil then
                self.descendants = {}

                local function collectAllDescendants(tag, visited)
                    visited = visited or {}
                    if visited[tag.id] then return end
                    visited[tag.id] = true
                    for candidateId, candidate in pairs(self.allTags) do
                        if candidate.parentId == tag.id then
                            table.insert(self.descendants, candidate)
                            collectAllDescendants(candidate, visited)
                        end
                    end
                end

                collectAllDescendants(self)
            end
        end
        self.tags[id].addParents = function(self)
            if self.parents == nil then
                self.parents = {}
                local current = self
                while current.parent do
                    table.insert(self.parents, 1, current.parent)
                    current = current.parent
                end
            end
        end
        self.tags[id].addSiblings = function(self)
            if self.siblings == nil then
                self.siblings = {}
                if self.parentId and self.parentId ~= TAGS_ROOT_PARENT then
                    for candidateId, candidate in pairs(self.allTags) do
                        if candidate.parentId == self.parentId and candidateId ~= self.id then
                            table.insert(self.siblings, candidate)
                        end
                    end
                end
            end
        end

        -- Move this tag to a new position relative to a target tag
        self.tags[id].moveTo = function(self, targetTag, position)
            -- Defensive checks
            if not targetTag or not position then
                self.app.logger:logError('moveTo: targetTag or position is nil')
                return false
            end
            if not targetTag.id then
                self.app.logger:logError('moveTo: targetTag.id is nil')
                return false
            end

            local tagInfo = self.app.userdata.current.tagInfo
            local oldParentId = self.parentId
            local oldOrder = self.order
            local newParentId

            self.app.logger:logDebug('move tag "' ..
                self.name .. '" to ' .. tostring(position) .. ' "' .. targetTag.name .. '"')

            -- Determine new parent
            if position == "inside" then
                newParentId = targetTag.id
                targetTag:toggleOpen(true, false)
                self.app.logger:logDebug('open "' .. targetTag.name .. '"')
            elseif position == "before" or position == "after" then
                newParentId = targetTag.parentId
                if targetTag.parent then
                    targetTag.parent:toggleOpen(true, false)
                    self.app.logger:logDebug('open "' .. targetTag.name .. '"')
                end
            else
                self.app.logger:logError('moveTo: invalid position "' .. tostring(position) .. '"')
                return false
            end

            -- Collect siblings under the new parent
            local siblings = {}
            for candidateId, candidate in OD_PairsByOrder(self.allTags) do
                if candidate.parentId == newParentId then
                    table.insert(siblings, candidateId)
                end
            end

            -- Remove self from siblings if present (for move)
            local filteredSiblings = {}
            for _, sibId in pairs(siblings) do
                if sibId ~= self.id then
                    table.insert(filteredSiblings, sibId)
                end
            end

            -- Find the target index in the filteredSiblings list
            local targetIndex = nil
            for i, sibId in ipairs(filteredSiblings) do
                if sibId == targetTag.id then
                    targetIndex = i
                    break
                end
            end

            -- Insert self at the correct position
            if position == "inside" then
                table.insert(filteredSiblings, 1, self.id)
            elseif position == "before" then
                -- If targetIndex is nil, insert at end (shouldn't happen, but fallback)
                table.insert(filteredSiblings, targetIndex or (#filteredSiblings + 1), self.id)
            elseif position == "after" then
                if targetIndex == nil then
                    -- fallback: append at end
                    table.insert(filteredSiblings, self.id)
                elseif targetIndex == #filteredSiblings then
                    -- after the last: append
                    table.insert(filteredSiblings, self.id)
                else
                    -- after: insert after targetIndex
                    table.insert(filteredSiblings, targetIndex + 1, self.id)
                end
            end

            -- Reorder all siblings (including self)
            for i, sibId in ipairs(filteredSiblings) do
                tagInfo[sibId].order = i
                if sibId == self.id then
                    tagInfo[sibId].parentId = newParentId
                end
            end

            -- If parent changed, reorder old parent's siblings as well
            if oldParentId ~= newParentId then
                local oldSiblings = {}
                for candidateId, candidate in OD_PairsByOrder(self.allTags) do
                    if candidate.parentId == oldParentId and candidate.id ~= self.id then
                        table.insert(oldSiblings, candidateId)
                    end
                end
                table.sort(oldSiblings, function(a, b) return tagInfo[a].order < tagInfo[b].order end)
                for i, sibId in ipairs(oldSiblings) do
                    tagInfo[sibId].order = i
                end
            end

            self.parentId = newParentId
            self.order = nil -- will be set by above loop

            self.app.userdata:save()
            -- Rescan tags into the engine after move
            self.engine:getTags(true)
        end
    end

    for id, tag in pairs(self.tags) do
        tag:addDescendants()
        tag:addParents()
    end

    for id, tag in pairs(self.tags) do
        tag:addSiblings()
    end

    for id, tag in pairs(self.tags) do
        tag.hasDescendants = tag.descendants ~= nil and next(tag.descendants)
    end

    if reassembleTagFilterAssets then self:assembleFilterAssets({ tags = true }) end
end

PB_DataEngine.getPresets = function(self, reassemblePresetFilterAssets)
    self.app.logger:logDebug('-- PB_DataEngine.getPresets()')

    self.presets = {}
    self.magicWords = {}

    -- Create a sorted list of presets alphabetically for consistent ordering
    local sortedPresets = {}
    for id, presetData in pairs(self.app.userdata.current.presets) do
        table.insert(sortedPresets, { id = id, data = presetData })
    end

    -- Sort alphabetically by name
    table.sort(sortedPresets, function(a, b)
        return a.data.name < b.data.name
    end)

    -- Process presets in sorted order and assign order field
    for order, sortedPreset in ipairs(sortedPresets) do
        local id = sortedPreset.id
        local presetData = sortedPreset.data
        if presetData.word and presetData.word ~= '' then
            self.magicWords[presetData.word:upper()] = presetData.filter
        end
        local preset = OD_DeepCopy(presetData)
        preset.id = id
        preset.app = self.app
        preset.engine = self
        preset.order = order -- Add dynamic order field for OD_PairsByOrder

        -- Add methods to preset
        preset.apply = function(self)
            -- Apply this preset's filter to the current search
            if self.filter then
                self.app.flow.filterResults(OD_DeepCopy(self.filter))
                self.app.logger:logInfo('Applied preset "' .. self.name .. '"')
            end
        end

        preset.update = function(self, newFilter)
            -- Update this preset with current filter
            self.app.userdata:updatePreset(self.id, newFilter or self.app.temp.filter)
        end

        preset.delete = function(self)
            self.app.userdata:deletePreset(self.id)
        end

        preset.rename = function(self, newName)
            self.app.userdata:renamePreset(self.id, newName)
        end

        -- Create a display name for this preset
        preset.displayName = preset.name

        self.presets[id] = preset
        self.app.logger:logDebug('Added preset "' .. preset.name .. '" with id ' .. id .. ' (order: ' .. order .. ')')
    end

    if reassemblePresetFilterAssets then self:assembleFilterAssets({ presets = true }) end

    -- Update the filter menu whenever presets change
    self:updatePresetsFilterMenu()
end

PB_DataEngine.refreshPresets = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.refreshPresets()')
    -- Simple wrapper around getPresets for external refresh calls
    self:getPresets(true)
end

PB_DataEngine.markSpecialGroups = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.markSpecialGroups()')

    local favoriteCount = 0
    local recentCount = 0

    -- Get current lists
    local favorites = self.app.userdata.current.favorites or {}
    local recents = self.app.userdata.current.recents or {}

    -- Clean up excess recents first
    local recentsToDelete = {}
    while #recents > self.app.settings.current.numberOfRecents do
        table.insert(recentsToDelete, recents[#recents])
        table.remove(recents, #recents)
    end

    -- Create lookup tables for better performance
    local favoritesLookup = {}
    for i, favoriteId in ipairs(favorites) do
        favoritesLookup[favoriteId] = i
    end

    local recentsLookup = {}
    for i, recentId in ipairs(recents) do
        recentsLookup[recentId] = i
    end

    local recentsToDeleteLookup = {}
    for _, deleteId in ipairs(recentsToDelete) do
        recentsToDeleteLookup[deleteId] = true
    end

    -- Process all assets
    for _, asset in ipairs(self.assets) do
        local favoriteIndex = favoritesLookup[asset.id]
        local recentIndex = recentsLookup[asset.id]
        local shouldDeleteFromRecents = recentsToDeleteLookup[asset.id]

        -- Clear any existing special group markings first
        if asset.group == SPECIAL_GROUPS.FAVORITES or asset.group == SPECIAL_GROUPS.RECENTS then
            if asset.originalGroup then
                asset.group = asset.originalGroup
                asset.originalGroup = nil
            end
            asset.favoriteOrder = nil
            asset.recentOrder = nil
            asset.favorite = nil
        end

        -- Handle removal from recents (assets that were recently used but exceeded the limit)
        if shouldDeleteFromRecents then
            self.app.logger:logDebug('Removing asset from recents: ' .. asset.id)
            -- Asset group should already be restored above
        end

        -- Mark recents first (takes priority over favorites for group assignment)
        if recentIndex then
            asset.originalGroup = asset.group
            asset.group = SPECIAL_GROUPS.RECENTS
            asset.recentOrder = recentIndex
            recentCount = recentCount + 1
            self.app.logger:logDebug('Marked asset as recent: ' .. asset.id .. ' (order: ' .. recentIndex .. ')')
            -- Mark favorites (only if not recent)
        elseif favoriteIndex then
            asset.originalGroup = asset.group
            asset.group = SPECIAL_GROUPS.FAVORITES
            asset.favoriteOrder = favoriteIndex
            self.app.logger:logDebug('Marked asset as favorite: ' .. asset.id .. ' (order: ' .. favoriteIndex .. ')')
        end

        -- Set favorite flag for all favorites, regardless of which group they're in
        if favoriteIndex then
            asset.favorite = true
            favoriteCount = favoriteCount + 1
            if recentIndex then
                self.app.logger:logDebug('Asset is both favorite and recent: ' .. asset.id .. ' (appears in recents)')
            end
        end
    end

    self.app.logger:logDebug('Marked special groups - Favorites: ' .. favoriteCount .. ', Recents: ' .. recentCount)
end

PB_DataEngine.tagAssets = function(self)
    for _, asset in ipairs(self.assets) do
        asset.tags = OD_DeepCopy(self.app.userdata.current.taggedAssets[asset.id]) or {}
    end
end

PB_DataEngine.assetsWithTag = function(self, tag)
    local assetsWithTag = {}
    for _, asset in ipairs(self.assets) do
        if OD_HasValue(asset.tags, tag.id) then
            table.insert(assetsWithTag, asset)
        end
    end
    return assetsWithTag
end

PB_DataEngine.assembleAssets = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.assembleAssets()')

    local assets, count = self.assetTypeManager:assembleAllAssets()
    self.assets = assets

    self:tagAssets()
    self:markSpecialGroups()
    self:sortAssets()
    self.app.logger:logInfo('A total of ' .. count .. ' assets were added to the database')
end
-- whichFilter example: {filters = {FILTER_TYPES.CATEGORY, FILTER_TYPES.DEVELOPER}, tags = true}
PB_DataEngine.assembleFilterAssets = function(self, whichFilters)
    self.app.logger:logDebug('-- PB_DataEngine.assembleFilterAssets()')
    local scanAll = whichFilters == nil and true or false
    local whichFilters = whichFilters or {}
    local executeFilter = function(self, context)
        if self.type ~= FILTER_TYPES.TAG then
            if OD_BfCheck(context, ImGui.Mod_Alt) then
                self.app.flow.filterResults(self.loadAll)
            else
                self.app.flow.filterResults(self.load)
            end
        else
            if OD_BfCheck(context, ImGui.Mod_Alt) then
                self.app.flow.filterResults({ removeTags = { self.load } })
            elseif OD_BfCheck(context, ImGui.Mod_Ctrl) then
                self.app.flow.filterResults({ addTags = { [self.load] = false } })
            else
                self.app.flow.filterResults({ addTags = { [self.load] = true } })
            end
        end
        if not OD_BfCheck(context, ImGui.Mod_Shift) then
            self.app.flow.setSearchMode(SEARCH_MODE.MAIN)
        else
            self.app.flow.filterResults({ clearText = true })
        end
    end

    if scanAll then
        self.filterAssets = {}
    else
        local i = 0
        for j = 1, #self.filterAssets do
            i = i + 1
            if self.filterAssets[i] then
                local filterAsset = self.filterAssets[i]
                if whichFilters.filters then
                    for _, filterType in ipairs(whichFilters.filters) do
                        if filterAsset.type ~= FILTER_TYPES.TAG and filterAsset.filter_type == filterType then
                            table.remove(self.filterAssets, i)
                            i = i - 1
                        end
                    end
                end
                if whichFilters.tags then
                    if filterAsset.type == FILTER_TYPES.TAG then
                        table.remove(self.filterAssets, i)
                        i = i - 1
                    end
                end
                if whichFilters.presets then
                    if filterAsset.type == FILTER_TYPES.PRESET then
                        table.remove(self.filterAssets, i)
                        i = i - 1
                    end
                end
            end
        end
    end

    local assetCount = 0

    if scanAll or whichFilters.filters then
        for filterType, filter in pairs(FILTER_MENU) do
            -- Skip presets here since they're handled separately with more functionality
            if filterType ~= FILTER_TYPES.PRESET and (scanAll or (whichFilters.filters and OD_HasValue(whichFilters.filters, filterType))) then
                for itemName, item in pairs(filter.items) do
                    table.insert(self.filterAssets, {
                        engine = self,
                        app = self.app, -- Add app context for executeFilter
                        type = filterType,
                        searchText = { { text = itemName } },
                        order = item.order,
                        load = item.query,
                        loadAll = filter.allQuery,
                        group = T.FILTER_NAMES[filterType],
                        execute = executeFilter
                    })
                    assetCount = assetCount + 1
                end
            end
        end
    end
    if scanAll or whichFilters.tags then
        if scanAll or whichFilters.tags then
            local count = 0
            local flatTags = {}

            -- Build parent->children index for O(1) lookup
            local childrenByParent = {}
            for tagId, tag in pairs(self.tags) do
                local parentId = tag.parentId
                if not childrenByParent[parentId] then
                    childrenByParent[parentId] = {}
                end
                table.insert(childrenByParent[parentId], { id = tagId, tag = tag })
            end

            -- Sort children by order within each parent group (only once per parent)
            for parentId, children in pairs(childrenByParent) do
                table.sort(children, function(a, b)
                    return a.tag.order < b.tag.order
                end)
            end

            -- Efficient recursive flatten using pre-built index
            local function flattenTagsOfParent(parentId)
                local children = childrenByParent[parentId]
                if not children then return end

                for _, child in ipairs(children) do
                    table.insert(flatTags, child.tag)
                    child.tag.order = count
                    count = count + 1
                    flattenTagsOfParent(child.id)
                end
            end

            flattenTagsOfParent(TAGS_ROOT_PARENT)

            for tagId, tag in pairs(flatTags) do
                table.insert(self.filterAssets, {
                    engine = self,
                    app = self.app, -- Add app context for executeFilter
                    type = FILTER_TYPES.TAG,
                    searchText = { { text = tag.name } },
                    parents = tag.parents,
                    order = tag.order,
                    load = tag.id,
                    group = T.FILTER_NAMES[FILTER_TYPES.TAG],
                    execute = executeFilter
                })
                assetCount = assetCount + 1
            end
        end
    end

    if scanAll or whichFilters.presets then
        local executePresetFilter = function(self, context)
            if OD_BfCheck(context or 0, ImGui.Mod_Alt) then
                -- Alt-click: Update preset with current filter
                self.preset:update()
                self.app.logger:logInfo('Updated preset "' .. self.preset.name .. '" with current filter')
            else
                -- Normal click: Apply preset
                self.preset:apply()
            end
            if not OD_BfCheck(context, ImGui.Mod_Shift) then
                self.app.flow.setSearchMode(SEARCH_MODE.MAIN)
            end
        end

        for presetId, preset in pairs(self.presets) do
            table.insert(self.filterAssets, {
                name = preset.name,
                engine = self,
                app = self.app,
                type = FILTER_TYPES.PRESET,
                searchText = { { text = preset.name } },
                order = preset.id, -- Use ID as order for now, could be customized later
                preset = preset,   -- Store reference to preset
                group = T.FILTER_NAMES[FILTER_TYPES.PRESET],
                execute = executePresetFilter
            })
            assetCount = assetCount + 1
        end
    end
    self:sortFilterAssets()
    if not scanAll and self.app.temp.searchMode == SEARCH_MODE.FILTERS then
        self.app.flow.filterResults()
    end
    self.app.logger:logInfo('A total of ' ..
        assetCount .. ' filter assets were ' .. (scanAll and 'added to ' or 'updated in ') .. 'the database')
end
PB_DataEngine.sortAssets = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.sortAssets()')

    -- Check if we need to rebuild the group priority cache
    -- Simple check: compare groupOrder table directly (not perfect but good enough)
    local currentGroupOrder = self.app.settings.current.groupOrder
    local needsRebuild = not self._groupPriorityCache or
        not self._lastGroupOrder or
        OD_TableLength(currentGroupOrder or {}) ~= OD_TableLength(self._lastGroupOrder)

    if needsRebuild then
        self.app.logger:logDebug('Rebuilding group priority cache')
        local groupPriority = {}

        -- Get group order - use setting if specified, otherwise build dynamically
        local groupOrder = currentGroupOrder
        if not groupOrder and self.assetTypeManager then
            groupOrder = self.assetTypeManager:buildDynamicGroupOrder()
        elseif not groupOrder then
            -- Fallback if no AssetTypeManager is available
            groupOrder = { SPECIAL_GROUPS.RECENTS, SPECIAL_GROUPS.FAVORITES, SPECIAL_GROUPS.PLUGINS }
        end

        -- Cache for resolved group names to avoid repeated lookups
        local groupNameCache = {}

        -- Helper function to resolve asset type class names to group names (with caching)
        local function resolveGroupName(item)
            if groupNameCache[item] then
                return groupNameCache[item]
            end

            local resolvedName

            -- If it's a special group constant, return as-is
            if item == SPECIAL_GROUPS.FAVORITES or item == SPECIAL_GROUPS.RECENTS or item == SPECIAL_GROUPS.PLUGINS then
                resolvedName = item
                -- If it looks like an asset type class name, resolve it to the actual group name
            elseif item:match("AssetType$") and self.assetTypeManager then
                local assetType = self.assetTypeManager:getAssetTypeByClassName(item)
                resolvedName = assetType and assetType.group or item
            else
                -- Otherwise, assume it's already a group name
                resolvedName = item
            end

            -- Cache the result (except for dynamic special groups)
            if item ~= SPECIAL_GROUPS.FAVORITES and item ~= SPECIAL_GROUPS.RECENTS then
                groupNameCache[item] = resolvedName
            end

            return resolvedName
        end

        -- Build the final group order by expanding PLUGINS_GROUP placeholder and resolving class names
        local finalGroupOrder = {}
        for i, group in ipairs(groupOrder) do
            if group == SPECIAL_GROUPS.PLUGINS then
                -- Insert FX types in their specified order
                for j, fxType in ipairs(self.app.settings.current.fxTypeOrder) do
                    table.insert(finalGroupOrder, fxType)
                end
            else
                -- Resolve asset type class names to actual group names
                local resolvedGroup = resolveGroupName(group)
                table.insert(finalGroupOrder, resolvedGroup)
            end
        end

        -- Assign priorities based on position in final order
        for i, group in ipairs(finalGroupOrder) do
            groupPriority[group] = i
        end

        -- Cache the results
        self._groupPriorityCache = groupPriority
        self._lastGroupOrder = OD_DeepCopy(currentGroupOrder)
        self.app.logger:logDebug('Group priority cache built with ' .. OD_TableLength(groupPriority) .. ' groups')
    end

    local groupPriority = self._groupPriorityCache

    table.sort(self.assets, function(a, b)
        local aPriority = groupPriority[a.group] or 1000
        local bPriority = groupPriority[b.group] or 1000
        if a.type == ASSET_TYPE.TrackAssetType and b.type == ASSET_TYPE.TrackAssetType and aPriority == bPriority then
            return a.order < b.order
        elseif aPriority == bPriority then
            -- Special handling for favorites: sort by favoriteOrder instead of alphabetically
            if a.group == SPECIAL_GROUPS.FAVORITES and b.group == SPECIAL_GROUPS.FAVORITES then
                return (a.favoriteOrder or 0) < (b.favoriteOrder or 0)
                -- Special handling for recents: sort by recentOrder instead of alphabetically
            elseif a.group == SPECIAL_GROUPS.RECENTS and b.group == SPECIAL_GROUPS.RECENTS then
                return (a.recentOrder or 0) < (b.recentOrder or 0)
            else
                return a.searchText[1].text < b.searchText[1].text
            end
        else
            return aPriority < bPriority
        end
    end)

    self.app.logger:logDebug('Sorted assets', #self.assets)
end

PB_DataEngine.sortFilterAssets = function(self)
    self.app.logger:logDebug('-- PB_DataEngine.sortFilterAssets()')
    local groupPriority = {}
    for filterType, filterMenu in pairs(FILTER_MENU) do
        groupPriority[filterType] = filterMenu.order
    end
    groupPriority[FILTER_TYPES.PRESET] = -2
    groupPriority[FILTER_TYPES.TAG] = -1

    table.sort(self.filterAssets, function(a, b)
        local aPriority = groupPriority[a.type] or 100
        local bPriority = groupPriority[b.type] or 100
        if a.order and aPriority == bPriority then
            return a.order < b.order
        elseif aPriority == bPriority then
            return a.searchText[1].text < b.searchText[1].text
        else
            return aPriority < bPriority
        end
    end)

    self.app.logger:logDebug('Sorted filter assets', #self.filterAssets)
end


PB_DataEngine.getFilterAssetByKey = function(self, filterType, key, value)
    for _, filterAsset in pairs(self.filterAssets) do
        if filterAsset.type == filterType and tostring(filterAsset[key]) == tostring(value) then
            return filterAsset
        end
    end
    return false
end