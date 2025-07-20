-- @noindex

DB = {
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
    refreshTracks = function(self)
        -- Helper function to refresh tracks using the modular system
        if self.assetTypeManager then
            local trackAssetType = self.assetTypeManager:getAssetTypeById(ASSETS.TRACK)
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
        self.app.logger:logDebug('-- DB.init()')
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

        if self.app.logger.profile then Profile.start() end

        self:getTags()

        -- Use the new modular assembleAssets
        self:assembleAssets()
        self:updateDevelopersFilterMenu()
        self:assembleFilterAssets()
        if self.app.logger.profile then
            Profile.stop()
            r.ShowConsoleMsg(Profile.report(10))
        end
    end,
    sync = function(self, refresh) -- not sure this is needed
        self.app.logger:logDebug('-- DB.sync()')
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

-- get project tracks into self.tracks, keeping the track's GUID, name and color, and wheather it has receives or not

DB.getSelectedTracks = function(self)
    self.app.logger:logDebug('-- DB.getSelectedTracks()')
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

DB._getTrack = function(self, track)
    self.app.logger:logDebug('-- DB._getTrack()')
    for i, trk in ipairs(self.tracks) do
        if track == trk.object then
            return trk
        end
    end
    self.app.logger:logDebug('Track not found in database')
    return nil
end

--- INSERTS
DB.recalculateShortNames = function(self)
    self.app.logger:logDebug('-- DB.recalculateShortNames()')
    local sendCount = 0
    for _, send in ipairs(self.sends) do
        if send.destTrack then
            for _, insert in ipairs(send.destTrack.inserts) do
                insert:calculateShortName()
            end
            send:calculateShortName()
            sendCount = sendCount + 1
        end
    end
    self.app.logger:logDebug('Recalculated short names for sends', sendCount)
end

DB.getFXFolders = function(self)
    self.app.logger:logDebug('-- DB.getFXFolders()')
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

DB.getFXCategories = function(self)
    self.app.logger:logDebug('-- DB.getFXCategories()')
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

DB.updateDevelopersFilterMenu = function(self)
    self.app.logger:logDebug('-- DB.updateDevelopersFilterMenu()')
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



-- TAGS AND FAVORITES
DB.getTags = function(self, reassembleTagFilterAssets)
    self.tags = OD_DeepCopy(self.app.tags.current.tagInfo)
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

    for id, tagInfo in pairs(self.app.tags.current.tagInfo) do
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
        self.tags[id].db = self

        self.tags[id].toggleOpen = function(self, state, persist)
            persist = (persist == nil) and true or persist
            self.open = state
            self.app.tags.current.tagInfo[self.id].open = state
            if persist then self.app.tags:save() end
        end
        self.tags[id].rename = function(self, name, persist)
            persist = (persist == nil) and true or persist
            self.name = name
            self.app.tags.current.tagInfo[self.id].name = name
            if persist then
                self.app.tags:save()
                self.db:getTags(true)
            end
        end
        self.tags[id].delete = function(self, persistAndReload)
            local assetsToRemoveTag = self.db:assetsWithTag(self)
            if self.app.temp.filter.tags then
                self.app.flow.filterResults({ removeTags = { self.id } })
            end
            for _, asset in pairs(assetsToRemoveTag) do
                asset:removeTag(self, false)
            end
            for _, tag in pairs(self.descendants) do
                tag:delete(false)
            end
            self.app.tags.current.tagInfo[self.id] = nil
            for sibId, sib in pairs(self.siblings) do
                if sib.order > self.order then
                    self.app.tags.current.tagInfo[sibId].order = self.app.tags.current.tagInfo[sibId].order - 1
                end
            end
            if persistAndReload ~= false then
                self.app.tags:save()
                self.db:getTags(true)
            end
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

            local tagInfo = self.app.tags.current.tagInfo
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

            self.app.tags:save()
            -- Rescan tags into the DB after move
            self.db:getTags(true)
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

DB.createTag = function(self, name, parent)
    self.app.logger:logDebug('-- DB.createTag()')
    self.app.logger:logDebug('Creating tag "' .. name .. '"')
    local parentId = (parent == TAGS_ROOT_PARENT) and TAGS_ROOT_PARENT or parent.id
    local levelCount = 0
    local lastId = 1
    for id, tagInfo in pairs(self.app.tags.current.tagInfo) do
        if tagInfo.parentId == parentId then
            levelCount = levelCount + 1
        end
        lastId = id
    end
    local newTag = {
        name = name,
        parentId = parentId,
        order = levelCount + 1
    }
    local newId = self.app.tags.current.idCount + 1
    self.app.tags.current.idCount = newId
    self.app.tags.current.tagInfo[newId] = newTag
    self.app.logger:logInfo('Created a new tag \'' ..
        name ..
        '\' with id ' ..
        newId .. (parentId ~= TAGS_ROOT_PARENT and ' (parent Id: ' .. parentId .. ')' or ''))
    self.app.tags:save()
    self:getTags(true)

    for _, tag in pairs(self.tags) do
        if tag.id == newId then
            return tag
        end
    end
end
DB.markFavorites = function(self)
    self.app.logger:logDebug('-- DB.markFavorites()')
    local favoriteCount = 0
    for _, asset in ipairs(self.assets) do
        if OD_HasValue(self.app.tags.current.favorites, asset.id) then
            asset.originalGroup = asset.group
            asset.group = SPECIAL_GROUPS.FAVORITES
            favoriteCount = favoriteCount + 1
        end
    end
    self.app.logger:logDebug('Marked favorites', favoriteCount)
end

DB.tagAssets = function(self)
    for _, asset in ipairs(self.assets) do
        asset.tags = OD_DeepCopy(self.app.tags.current.taggedAssets[asset.id]) or {}
    end
end

DB.assetsWithTag = function(self, tag)
    local assetsWithTag = {}
    for _, asset in ipairs(self.assets) do
        if OD_HasValue(asset.tags, tag.id) then
            table.insert(assetsWithTag, asset)
        end
    end
    return assetsWithTag
end

DB.assembleAssets = function(self)
    self.app.logger:logDebug('-- DB.assembleAssets()')

    local assets, count = self.assetTypeManager:assembleAllAssets()
    self.assets = assets

    self:tagAssets()
    self:markFavorites()
    self:sortAssets()
    self.app.logger:logInfo('A total of ' .. count .. ' assets were added to the database')
end
-- whichFilter example: {filters = {FILTER_TYPES.CATEGORY, FILTER_TYPES.DEVELOPER}, tags = true}
DB.assembleFilterAssets = function(self, whichFilters)
    self.app.logger:logDebug('-- DB.assembleFilterAssets()')
    local scanAll = whichFilters == nil and true or false
    local whichFilters = whichFilters or {}
    local executeFilter = function(self, context)
        if self.type ~= FILTER_TYPES.TAG then
            if context == RESULT_CONTEXT.ALT then
                self.db.app.flow.filterResults(self.loadAll)
            else
                self.db.app.flow.filterResults(self.load)
            end
        else
            if context == RESULT_CONTEXT.ALT then
                self.db.app.flow.filterResults({ removeTags = { self.load } })
            elseif context == RESULT_CONTEXT.CTRL then
                self.db.app.flow.filterResults({ addTags = { [self.load] = false } })
            else
                self.db.app.flow.filterResults({ addTags = { [self.load] = true } })
            end
        end
        if context ~= RESULT_CONTEXT.SHIFT then
            self.db.app.flow.setSearchMode(SEARCH_MODE.MAIN)
        else
            self.db.app.flow.filterResults({ clearText = true })
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
            end
        end
    end

    local assetCount = 0

    if scanAll or whichFilters.filters then
        for filterType, filter in pairs(FILTER_MENU) do
            if scanAll or (whichFilters.filters and OD_HasValue(whichFilters.filters, filterType)) then
                for itemName, item in pairs(filter.items) do
                    table.insert(self.filterAssets, {
                        db = self,
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
                    db = self,
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
    self:sortFilterAssets()
    if not scanAll and self.app.temp.searchMode == SEARCH_MODE.FILTERS then
        self.app.flow.filterResults()
    end
    self.app.logger:logInfo('A total of ' ..
        assetCount .. ' filter assets were ' .. (scanAll and 'added to ' or 'updated in ') .. 'the database')
end
DB.sortAssets = function(self)
    self.app.logger:logDebug('-- DB.sortAssets()')
    local groupPriority = {}
    
    -- Get group order - use setting if specified, otherwise build dynamically
    local groupOrder = self.app.settings.current.groupOrder
    if not groupOrder and self.assetTypeManager then
        groupOrder = self.assetTypeManager:buildDynamicGroupOrder()
    elseif not groupOrder then
        -- Fallback if no AssetTypeManager is available
        groupOrder = {SPECIAL_GROUPS.RECENTS, SPECIAL_GROUPS.FAVORITES, SPECIAL_GROUPS.PLUGINS}
    end
    
    -- Build the final group order by expanding PLUGINS_GROUP placeholder
    local finalGroupOrder = {}
    for i, group in ipairs(groupOrder) do
        if group == SPECIAL_GROUPS.PLUGINS then
            -- Insert FX types in their specified order
            for j, fxType in ipairs(self.app.settings.current.fxTypeOrder) do
                table.insert(finalGroupOrder, fxType)
            end
        else
            table.insert(finalGroupOrder, group)
        end
    end
    
    -- Assign priorities based on position in final order
    for i, group in ipairs(finalGroupOrder) do
        groupPriority[group] = i
    end

    table.sort(self.assets, function(a, b)
        local aPriority = groupPriority[a.group] or 1000
        local bPriority = groupPriority[b.group] or 1000
        if a.type == ASSETS['TRACK'] and b.type == ASSETS['TRACK'] and aPriority == bPriority then
            return a.order < b.order
        elseif aPriority == bPriority then
            return a.searchText[1].text < b.searchText[1].text
        else
            return aPriority < bPriority
        end
    end)

    self.app.logger:logDebug('Sorted assets', #self.assets)
end

DB.sortFilterAssets = function(self)
    self.app.logger:logDebug('-- DB.sortFilterAssets()')
    local groupPriority = {}
    for filterType, filterMenu in pairs(FILTER_MENU) do
        groupPriority[filterType] = filterMenu.order
    end
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
