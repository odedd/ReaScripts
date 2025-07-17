-- @noindex

DB = {
    plugins = {},
    fxChains = {},
    trackTemplates = {},
    tracks = {},
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
    lastGuids = {}, -- use to check if a track has been removed or added
    init = function(self, app)
        self.app.logger:logDebug('-- DB.init()')
        self.plugins = {}
        self.tracks = {}
        self.masterTrack = reaper.GetMasterTrack(0)
        if Profile then Profile.start() end
        self:getPlugins()
        self:getFXChains()
        self:getFXFolders()
        self:getFXCategories()
        self:getAllActions()
        self:getTrackTemplates()
        self:getTracks()
        self:getTags()
        self:assembleAssets()
        self:updateDevelopersFilterMenu()
        self:assembleFilterAssets()
        if Profile then
            Profile.stop()
            r.ShowConsoleMsg(Profile.report(10))
        end
    end,
    sync = function(self, refresh)                             -- not sure this is needed
        self.refresh = refresh or false
        self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force full sync
        if self.current_project ~= self.previous_project then
            self:getTracks()
            self.previous_project = self.current_project
            self.refresh = true
        end

        if self.refresh then
            self.app.setPage(APP_PAGE.SEARCH)
        end
    end
}

--- Sends

DB.createNewSend = function(self, sendType, assetType, assetLoad, trackName)
    self:beginUndoBlock()
    -- if sendType == SEND_TYPE.HW then
    --     local sndIdx = reaper.CreateTrackSend(self.track.object, nil)
    --     reaper.SetTrackSendInfo_Value(self.track.object, sendType, sndIdx, 'I_DSTCHAN', assetType)
    --     self:sync(true)
    --     return
    -- end
    if assetType == ASSETS.TRACK_TEMPLATE then
        -- since track templates are loaded under the last selected track,
        -- and as root folders, I need to create a new dummy track inside the folder,
        -- calculate its depth, insert the tracktemplate, move it after the dummy track,
        -- calculate its depth change, and apply it + the depth change from the dummy track,
        -- and then delete the dummy track
        local dummyTrack, dummyTrackFolderDepth, depthDelta = nil, 0, 0
        if self.app.settings.current.createInsideFolder then
            local folderFound = false
            local numTracks = r.CountTracks(0)
            for i = 0, numTracks - 1 do
                local track = r.GetTrack(0, i)
                local _, trackName = r.GetTrackName(track)
                if trackName == self.app.settings.current.sendFolderName then
                    folderFound = true
                    dummyTrack = OD_InsertTrackAtFolder(track)
                    r.SetOnlyTrackSelected(dummyTrack)
                    r.Main_OnCommand(40913, 0)
                    break
                end
            end

            if not folderFound then
                r.InsertTrackAtIndex(numTracks, true)
                local folder = r.GetTrack(0, numTracks)
                r.GetSetMediaTrackInfo_String(folder, 'P_NAME', self.app.settings.current.sendFolderName, true)
                dummyTrack = OD_InsertTrackAtFolder(folder)
                r.SetOnlyTrackSelected(dummyTrack)
                r.Main_OnCommand(40913, 0)
            end
            self:getTracks()
        else
            r.SetOnlyTrackSelected(r.GetTrack(0, r.CountTracks(0) - 1))
            r.Main_OnCommand(40913, 0)
        end
        local tempGuids = {}
        for _, track in ipairs(self.tracks) do
            table.insert(tempGuids, track.guid)
        end

        reaper.Main_openProject(assetLoad)

        if dummyTrack then
            dummyTrackFolderDepth = r.GetMediaTrackInfo_Value(dummyTrack, 'I_FOLDERDEPTH')
            r.SetMediaTrackInfo_Value(dummyTrack, 'I_FOLDERDEPTH', 0)
        end

        self:getTracks()

        local addedTracks = {}
        local lastTrack = nil
        for _, track in ipairs(self.tracks) do
            if not OD_HasValue(tempGuids, track.guid) then
                table.insert(addedTracks, track)
                if dummyTrack then
                    depthDelta = r.GetMediaTrackInfo_Value(track.object, 'I_FOLDERDEPTH')
                    lastTrack = track.object
                end
            end
        end
        if dummyTrack then
            r.SetMediaTrackInfo_Value(lastTrack, 'I_FOLDERDEPTH', dummyTrackFolderDepth + depthDelta)
            r.DeleteTrack(dummyTrack)
        end
        for _, addedTrack in ipairs(addedTracks) do
            reaper.CreateTrackSend(self.track.object, addedTrack.object)
        end

        r.SetOnlyTrackSelected(self.track.object)
        r.Main_OnCommand(40913, 0)
        self:sync(true)
    elseif assetType == ASSETS.TRACK then
        -- local sendTrackIndex = asset.load
        local targetTrack = OD_GetTrackFromGuid(0, assetLoad)
        if targetTrack then
            if sendType == SEND_TYPE.SEND then
                reaper.CreateTrackSend(self.track.object, targetTrack)
            elseif sendType == SEND_TYPE.RECV then
                reaper.CreateTrackSend(targetTrack, self.track.object)
            end
        end
        self:sync(true)
    elseif assetType == ASSETS.PLUGIN or assetType == ASSETS.FX_CHAIN then
        local newTrack = nil
        local numTracks = r.CountTracks(0)
        if self.app.settings.current.createInsideFolder then
            local folderFound = false
            for i = 0, numTracks - 1 do
                local track = r.GetTrack(0, i)
                local _, trackName = r.GetTrackName(track)
                if trackName == self.app.settings.current.sendFolderName then
                    folderFound = true
                    newTrack = OD_InsertTrackAtFolder(track)
                    break
                end
            end

            if not folderFound then
                r.InsertTrackAtIndex(numTracks, true)
                local folder = r.GetTrack(0, numTracks)
                r.GetSetMediaTrackInfo_String(folder, 'P_NAME', self.app.settings.current.sendFolderName, true)
                newTrack = OD_InsertTrackAtFolder(folder)
            end
        else
            r.InsertTrackAtIndex(numTracks, true)
            newTrack = r.GetTrack(0, numTracks)
        end
        if newTrack then
            reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", trackName, true)
            local rv = reaper.CreateTrackSend(self.track.object, newTrack)
            self:getTracks()
            r.SetOnlyTrackSelected(self.track.object)
            self:sync(true)
            for _, send in ipairs(self.sends) do
                if send.destTrack ~= nil and (send.destTrack.object == newTrack) then
                    send:addInsert(assetLoad)
                end
            end
        end
    end
    self:endUndoBlock('Create new send', 1)
end

--- TRACKS

-- get project tracks into self.tracks, keeping the track's GUID, name and color, and wheather it has receives or not

DB.getSelectedTracks = function(self)
    self:getTracks()
    local numTracks = r.CountSelectedTracks(0);
    local tracks = {};
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

DB.getTracks = function(self)
    self.app.logger:logDebug('-- DB.getTracks()')
    -- self:sync()
    self.tracks = {}
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        -- if track ~= self.track then
        local trackName = select(2, reaper.GetTrackName(track))
        local trackGuid = reaper.GetTrackGUID(track)
        self.app.logger:logDebug('Track added', trackName)
        local track = {
            object = track,
            db = self,
            guid = trackGuid,
            order = i,
            numInserts = 0,
            inserts = {},
            addInsert = function(self, fxName) -- undo point is created by TrackFX_AddByName
                local fxIndex = r.TrackFX_AddByName(self.object, fxName, false, -1)
                if fxIndex == -1 then
                    self.db.app.logger:logError('Cannot add ' .. fxName .. ' to ' .. trackName)
                    return false
                end
                self.db:sync(true)
                return true
            end,
            _refreshColor = function(self)
                local color = ImGui.ColorConvertNative(reaper.GetTrackColor(track)) * 0x100 | 0xff
                self.color = color
            end,
            _refreshName = function(self)
                self.name = select(2, reaper.GetTrackName(self.object))
            end,
            getInsertAtIndex = function(self, index)
                for i, insert in ipairs(self.inserts) do
                    if insert.order == index then
                        return insert
                    end
                end
            end,
            getInserts = function(self)
                self.numInserts = r.TrackFX_GetCount(self.object)
                self.inserts = {}
                for i = 0, self.numInserts - 1 do
                    local _, fxName = r.TrackFX_GetFXName(self.object, i, '')
                    local offline = r.TrackFX_GetOffline(self.object, i)
                    local enabled = r.TrackFX_GetEnabled(self.object, i)
                    local insert =
                    {
                        order = i,
                        db = self.db,
                        name = fxName,
                        shortName = fxName,
                        shortened = false,
                        calculateShortName = function(self)
                            ImGui.PushFont(self.db.app.gui.ctx, self.db.app.gui.st.fonts.small)
                            self.shortName, self.shortened = self.db.app.minimizeText(
                                self.name:gsub('.-%:', ''):gsub('%(.-%)$', ''):gsub("^%s+", ''):gsub("%s+$", ''),
                                math.floor(self.db.app.settings.current.sendWidth * self.db.app.settings.current.uiScale) -
                                r.ImGui_GetStyleVar(self.db.app.gui.ctx, r.ImGui_StyleVar_FramePadding()) * 4)
                            ImGui.PopFont(self.db.app.gui.ctx)
                        end,
                        offline = offline,
                        enabled = enabled,
                        track = self,
                        setEnabled = function(self, enabled) -- undo point created by TrackFX_SetEnabled
                            r.TrackFX_SetEnabled(self.track.object, i, enabled)
                            self.db:sync(true)
                        end,
                        setOffline = function(self, offline) -- undo point created by TrackFX_SetOffline
                            r.TrackFX_SetOffline(self.track.object, i, offline)
                            self.db:sync(true)
                        end,
                        delete = function(self) -- undo point created by TrackFX_Delete
                            r.TrackFX_Delete(self.track.object, i)
                            self.db:sync(true)
                        end,
                        toggleShow = function(self) -- showing FX does not create undo points
                            if not r.TrackFX_GetOpen(self.track.object, i) then
                                r.TrackFX_Show(self.track.object, i, 3)
                                return true
                            else
                                r.TrackFX_Show(self.track.object, i, 2)
                                return false
                            end
                        end,
                        moveToIndex = function(self, index) -- undo point created by TrackFX_Move
                            r.TrackFX_CopyToTrack(self.track.object, self.order, self.track.object, index, true)
                            self.db:sync()
                        end,
                    }
                    insert:calculateShortName()
                    table.insert(self.inserts, insert)
                end
            end
        }
        track:_refreshName()
        track:_refreshColor()
        table.insert(self.tracks, track)
        -- end
    end
    self.app.logger:logDebug('Found ' .. numTracks .. ' tracks')
end

DB._getTrack = function(self, track)
    for i, trk in ipairs(self.tracks) do
        if track == trk.object then
            return trk
        end
    end
end

--- INSERTS
DB.recalculateShortNames = function(self)
    for _, send in ipairs(self.sends) do
        if send.destTrack then
            for _, insert in ipairs(send.destTrack.inserts) do
                insert:calculateShortName()
            end
            send:calculateShortName()
        end
    end
end

--- PLUGINS
DB.addPlugin = function(self, full_name, fx_type, instrument, ident)
    -- TODO: check about all plugin types
    self.app.logger:logDebug('-- DB.addPlugin()')
    local self = self

    local function extractNameVendor(full_name, fx_type)
        self.app.logger:logDebug('-- DB.addPlugin() -> extractNameVendor()')
        local name, vendor
        local t = {}

        self.app.logger:logDebug('Parsing:', full_name)
        name = (fx_type == 'Internal') and full_name or full_name:match(fx_type .. ': (.*)$')
        if not fx_type:match('^JS') and fx_type ~= 'Internal' and fx_type ~= 'ReWire' then
            local counter = 1
            for w in string.gmatch(full_name, "%b()") do
                t[counter] = w:match("%((.-)%)$")
                counter = counter + 1
            end
        end
        vendor = t[#t]

        if vendor == nil and name == nil and (#t == 0) then return false end
        if not fx_type:match('^JS') then
            if fx_type ~= 'Internal' and fx_type ~= 'ReWire' then
                if next(t) ~= nil and (tostring(t[#t]):match('.-%dch$') or tostring(t[#t]):match('%d*%sout$') or tostring(t[#t]) == 'mono') then
                    vendor = t[#t - 1]
                end
                name = vendor and name:gsub(' %(' .. OD_EscapePattern(vendor) .. '%).-$', '') or name
            end
        end
        if vendor ~= '' and vendor ~= nil then
            self.fxDevelopers = self.fxDevelopers or {}
            self.fxDevelopers[vendor] = true
        end
        return true, name, (vendor == '' and nil or vendor)
    end

    if full_name == '' then return false end

    local success, name, vendor = extractNameVendor(full_name, fx_type)

    if success then
        self.app.logger:logDebug('Parsing successful')
        self.app.logger:logDebug('Name', name)
        self.app.logger:logDebug('Vendor', vendor)
    else
        self.app.logger:logError('Cannot parse plugin name', full_name)
        return false
    end

    local plugin = {
        full_name = full_name,
        fx_type = fx_type,
        name = name,
        vendor = vendor,
        ident = ident,
    }
    table.insert(self.plugins, plugin)
    self.app.logger:logDebug('Added ' ..
        fx_type .. (instrument and 'i' or '') .. ': ' .. name .. (vendor and (' by ' .. vendor) or ''),
        full_name)
    return plugin
end

DB.getFXChains = function(self)
    self.app.logger:logDebug('-- DB.getFXChains()')
    self.fxChains = {}
    local basePath = reaper.GetResourcePath() .. "/FXChains/"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'rfxchain', true)
    local count = 0
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local chainPath = path:gsub('\\', '/'):gsub('/$', '')
        self.app.logger:logDebug('Found FX chain', file)
        table.insert(self.fxChains, {
            load = file,
            path = chainPath,
            file = baseFilename,
            ext = ext
        })
        count = count + 1
    end
    self.app.logger:logInfo('Found ' .. count .. ' FX chains')
end
DB.getAllActions = function(self, section)
    self.app.logger:logDebug('-- DB.getAllActions()')
    self.actions = {}
    local idx = 0
    section = section or 0 -- default to main section if not provided
    while true do
        local cmdId, name = reaper.kbd_enumerateActions(section, idx)
        if cmdId == 0 then break end
        local prefix, actionName = name:match("^(.-):%s*(.*)$")
        if not prefix then
            prefix = ""
            actionName = name
        end
        name = actionName
        -- Get keyboard shortcuts for this action
        local shortcuts = {}
        local shortcutCount = reaper.CountActionShortcuts(section, cmdId)
        for sc = 0, shortcutCount - 1 do
            local rv, desc = reaper.GetActionShortcutDesc(section, cmdId, sc)
            if desc and desc ~= "" then
                table.insert(shortcuts, desc)
            end
        end

        table.insert(self.actions, {
            id = cmdId,
            order = idx,
            name = name,
            prefix = prefix,
            section = section,
            shortcuts = shortcuts
        })
        idx = idx + 1
    end
    self.app.logger:logInfo('Found ' .. #self.actions .. ' actions in section ' .. tostring(section))
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
end

DB.getTrackTemplates = function(self)
    self.app.logger:logDebug('-- DB.getTrackTemplates()')
    self.trackTemplates = {}
    local basePath = reaper.GetResourcePath() .. "/TrackTemplates"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'RTrackTemplate', true)
    local count = 0
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local ttLoad, ttPath = basePath .. OD_FolderSep() .. file, path:gsub('\\', '/'):gsub('/$', '')
        self.app.logger:logDebug('Found track template', ttLoad)
        table.insert(self.trackTemplates, {
            load = ttLoad,
            path = ttPath,
            file = baseFilename,
            ext = ext
        })
        count = count + 1
    end
    self.app.logger:logInfo('Found ' .. count .. ' track templates')
end
DB.getPlugins = function(self)
    self.app.logger:logDebug('-- DB.getPlugins()')
    local i = 0
    while true do
        local found, name, ident = reaper.EnumInstalledFX(i)
        local fx_type = name:match('(.-):%s') or 'Internal'
        local instrument = false
        if fx_type:sub(-1) == 'i' then
            instrument = true
        end
        local plugin = self:addPlugin(name, fx_type, instrument, ident)
        if plugin then
            plugin.group = plugin.fx_type
        end
        i = i + 1
        if not found then break end
    end
    self.app.logger:logInfo('Found ' .. i .. ' plugins')
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
                self.app.filterResults({ removeTags = { self.id } })
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
    self.db:getTags(true)

    for _, tag in pairs(self.tags) do
        if tag.id == newId then
            return tag
        end
    end
end
DB.markFavorites = function(self)
    for _, asset in ipairs(self.assets) do
        if OD_HasValue(self.app.tags.current.favorites, asset.id) then
            asset.originalGroup = asset.group
            asset.group = FAVORITE_GROUP
        end
    end
end
-- ASSETS
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
            self.group = FAVORITE_GROUP
        end
        self.db.app.tags:save()
        self.db:sortAssets()
        return self.group == FAVORITE_GROUP
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
    end,
    executeFilter = function(self, context)
        if self.type ~= FILTER_TYPES.TAG then
            if context == RESULT_CONTEXT.ALT then
                self.db.app.filterResults(self.loadAll)
            else
                self.db.app.filterResults(self.load)
            end
        else
            if context == RESULT_CONTEXT.ALT then
                self.db.app.filterResults({ removeTags = { self.load } })
            elseif context == RESULT_CONTEXT.CTRL then
                self.db.app.filterResults({ addTags = { [self.load] = false } })
            else
                self.db.app.filterResults({ addTags = { [self.load] = true } })
            end
        end
        if context ~= RESULT_CONTEXT.SHIFT then
            self.db.app.setSearchMode(SEARCH_MODE.MAIN)
        else
            self.db.app.filterResults({ clearText = true})
        end
    end,
    execute = function(self, context, contextData)
        if self.type == ASSETS.PLUGIN then
            if context == RESULT_CONTEXT.MAIN then
                local tracks = self.db:getSelectedTracks()
                for i = 1, #tracks do
                    tracks[i]:addInsert(self.load)
                end
            end
        elseif self.type == ASSETS.ACTION then
            r.Main_OnCommand(self.load, 0)
        elseif self.type == ASSETS.TRACK then
            -- r.SetOnlyTrackSelected(self.load)
        end
        self.db.app.selectSearchInputText()
    end
}

DB.assembleAssets = function(self)
    self.app.logger:logDebug('-- DB.assembleAssets()')
    self.assets = {}
    self.assetsWithTag = function(self, tag)
        local assetsWithTag = {}
        for _, asset in ipairs(self.assets) do
            if OD_HasValue(asset.tags, tag.id) then
                table.insert(assetsWithTag, asset)
            end
        end
        return assetsWithTag
    end



    local count = 0
    for _, chain in ipairs(self.fxChains) do
        table.insert(self.assets, {
            db = self,
            type = ASSETS.FX_CHAIN,
            searchText = { { text = chain.file }, { text = chain.path }, { text = chain.ext, hide = true } },
            load = chain.load,
            group = FX_CHAINS_GROUP,
        })
        count = count + 1
    end
    for _, tt in ipairs(self.trackTemplates) do
        table.insert(self.assets, {
            db = self,
            type = ASSETS.TRACK_TEMPLATE,
            searchText = { { text = tt.file }, { text = tt.path }, { text = tt.ext, hide = true } },
            load = tt.load,
            group = TRACK_TEMPLATES_GROUP,
        })
        count = count + 1
    end
    for _, track in ipairs(self.tracks) do
        table.insert(self.assets, {
            db = self,
            type = ASSETS.TRACK,
            searchText = { { text = track.name } },
            load = track.guid,
            group = TRACKS_GROUP,
            order = track.order,
            color = track.color,
        })
        count = count + 1
    end
    for _, action in ipairs(self.actions) do
        table.insert(self.assets, {
            db = self,
            type = ASSETS.ACTION,
            searchText = { { text = action.name }, { text = action.prefix or '' } },
            load = action.id,
            shortcuts = action.shortcuts,
            group = ACTIONS_GROUP,
            order = action.order,
        })
        count = count + 1
    end
    for _, plugin in ipairs(self.plugins) do
        if self.app.settings.current.fxTypeVisibility[plugin.fx_type] then
            table.insert(self.assets, {
                db = self,
                type = ASSETS.PLUGIN,
                -- searchText = { { text = plugin.name }, { text = plugin.vendor or '' }, { text = plugin.fx_type, hide = true } },
                searchText = { { text = plugin.name }, { text = plugin.vendor or '' } },
                load = plugin.ident,
                -- categoryPluginID = categoryPluginID,
                group = plugin.group,
                vendor = plugin.vendor,
                fx_type = plugin.fx_type,
                categories = {}, -- for use with caching when filtering occurs
                folders = {},    -- for use with caching when filtering occurs
                isInCategory = function(self, categoryName)
                    -- caching so that time intensive search only happens on the first filtering
                    if self.categories[categoryName] ~= nil then
                        return self.categories[categoryName]
                    end
                    local path, file, ext = OD_DissectFilename(self.load)
                    local categoryPluginID = (file .. '.' .. ext):gsub('[ -]', '_')

                    if self.db.pluginToCategories[categoryPluginID] then
                        self.categories[categoryName] = OD_HasValue(self.db.pluginToCategories[categoryPluginID],
                            categoryName)
                    else
                        self.categories[categoryName] = false
                    end
                    return self.categories[categoryName]
                end,
                isInFolder = function(self, folderId)
                    -- caching so that time intensive search only happens on the first filtering
                    if self.folders[folderId] ~= nil then
                        return self.folders[folderId]
                    end

                    if self.db.pluginToFolders[self.load] then
                        self.folders[folderId] = OD_HasValue(self.db.pluginToFolders[self.load],
                            folderId)
                    else
                        self.folders[folderId] = false
                    end
                    return self.folders[folderId]
                end,
            })
            count = count + 1
        end
    end
    for _, asset in ipairs(self.assets) do
        asset.id = asset.type .. ' ' .. asset.load
        asset.tags = OD_DeepCopy(self.app.tags.current.taggedAssets[asset.id]) or {}
        asset.addTag = assetActions.addTag
        asset.removeTag = assetActions.removeTag
        asset.execute = assetActions.execute
        asset.toggleFavorite = assetActions.toggleFavorite
    end

    self:markFavorites()
    self:sortAssets()
    self.app.logger:logInfo('A total of ' .. count .. ' assets were added to the database')
end
-- whichFilter example: {filters = {FILTER_TYPES.CATEGORY, FILTER_TYPES.DEVELOPER}, tags = true}
DB.assembleFilterAssets = function(self, whichFilters)
    self.app.logger:logDebug('-- DB.assembleFilterAssets()')
    local scanAll = whichFilters == nil and true or false
    local whichFilters = whichFilters or {}

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
                        execute = assetActions.executeFilter
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
            -- flatten tags
            local function flattenTagsOfParent(parentId)
                for tagId, tag in OD_PairsByOrder(self.tags) do
                    if tag.parentId == parentId then
                        table.insert(flatTags, tag)
                        tag.order = count
                        count = count + 1
                        flattenTagsOfParent(tagId)
                    end
                end
            end

            flattenTagsOfParent(TAGS_ROOT_PARENT)

            for tagId, tag in pairs(flatTags) do
                table.insert(self.filterAssets, {
                    db = self,
                    type = FILTER_TYPES.TAG,
                    searchText = { { text = tag.name } },
                    descendants = tag.descendants,
                    order = tag.order,
                    load = tag.id,
                    group = T.FILTER_NAMES[FILTER_TYPES.TAG],
                    execute = assetActions.executeFilter
                })
                assetCount = assetCount + 1
            end
        end
    end
    self:sortFilterAssets()
    if not scanAll and self.app.temp.searchMode == SEARCH_MODE.FILTERS then
        self.app.filterResults()
    end
    self.app.logger:logInfo('A total of ' ..
        assetCount .. ' filter assets were ' .. (scanAll and 'added to ' or 'updated in ') .. 'the database')
end
DB.sortAssets = function(self)
    local groupPriority = {}
    for i, group in ipairs(self.app.settings.current.fxTypeOrder) do
        groupPriority[group] = i
    end
    groupPriority[FX_CHAINS_GROUP] = -3
    groupPriority[TRACKS_GROUP] = -2
    groupPriority[TRACK_TEMPLATES_GROUP] = -1
    groupPriority[FAVORITE_GROUP] = -4
    groupPriority[ACTIONS_GROUP] = 10

    table.sort(self.assets, function(a, b)
        local aPriority = groupPriority[a.group] or 100
        local bPriority = groupPriority[b.group] or 100
        if a.type == ASSETS['TRACK'] and b.type == ASSETS['TRACK'] and aPriority == bPriority then
            return a.order < b.order
        elseif aPriority == bPriority then
            return a.searchText[1].text < b.searchText[1].text
        else
            return aPriority < bPriority
        end
    end)
end

DB.sortFilterAssets = function(self)
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
end
