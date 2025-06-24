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
        self:getPlugins()
        self:getFXChains()
        self:getTrackTemplates()
        self:getTracks()
        self:getTags()
        self:assembleAssets()
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
            self.app.setPage(APP_PAGE.SEARCH_FX)
        end
    end
}

--- Sends

DB.createNewSend = function(self, sendType, assetType, assetLoad, trackName)
    self:beginUndoBlock()
    if sendType == SEND_TYPE.HW then
        local sndIdx = reaper.CreateTrackSend(self.track.object, nil)
        reaper.SetTrackSendInfo_Value(self.track.object, sendType, sndIdx, 'I_DSTCHAN', assetType)
        self:sync(true)
        return
    end
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
                self.db.app.focusMainReaperWindow = false
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

DB.getTags = function(self)
    self.tags = OD_DeepCopy(self.app.tags.current.tagInfo)
    for id, tagInfo in pairs(self.app.tags.current.tagInfo) do
        if tagInfo.parentId and self.tags[tagInfo.parentId] then
            self.tags[id].parent = self.tags[tagInfo.parentId]
            self.tags[id].parent.children = self.tags[id].parent.children or {}
            -- self.tags[id].toplevel = false
            table.insert(self.tags[id].parent.children, self.tags[id])
            self.app.logger:logDebug('Added "' ..
            self.tags[id].name .. '" (parent: "' .. self.tags[id].parent.name .. '")')
        elseif tagInfo.parentId then
            -- self.tags[id].toplevel = true
            self.app.logger:logError('Illegal parent ID for tag "' .. self.tags[id].name .. '"')
        else
            -- self.tags[id].toplevel = true
            self.app.logger:logDebug('Added "' .. self.tags[id].name .. '"')
        end
        self.tags[id].id = id
        self.tags[id].app = self.app

        local col = self.tags[id].color
        local hoveredCol = OD_OffsetRgbaByHSL(col,0,0,0.06)
        local activeCol = OD_OffsetRgbaByHSL(col,0,0,0.1)
        local textCol = OD_ColorIsBright(col) and 0x000000ff or 0xffffffff
        self.tags[id].colors = {[ImGui.Col_Button] = col,
            [ImGui.Col_ButtonHovered] = hoveredCol,
            [ImGui.Col_ButtonActive] = activeCol,
            [ImGui.Col_Text] = textCol}
        self.tags[id].toggleOpen = function(self, state)
            self.open = state
            self.app.tags.current.tagInfo[id].open = state
            self.app.tags:save()
            -- body
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

DB.assembleAssets = function(self)
    self.app.logger:logDebug('-- DB.assembleAssets()')
    self.assets = {}

    local toggleFavorite = function(self)
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
    end
    local count = 0
    for _, chain in ipairs(self.fxChains) do
        table.insert(self.assets, {
            db = self,
            type = ASSETS.FX_CHAIN,
            searchText = { { text = chain.file }, { text = chain.path }, { text = chain.ext, hide = true } },
            load = chain.load,
            group = FX_CHAINS_GROUP,
            toggleFavorite = toggleFavorite
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
            toggleFavorite = toggleFavorite
        })
        count = count + 1
    end
    for _, track in ipairs(self.tracks) do
        table.insert(self.assets, {
            db = self,
            type = ASSETS.TRACK,
            searchText = { { text = track.name } },
            load = track.guid,
            group = track.hasReceives and RECEIVES_GROUP or TRACKS_GROUP,
            order = track.order,
            color = track.color,
            toggleFavorite = toggleFavorite
        })
        count = count + 1
    end
    for _, plugin in ipairs(self.plugins) do
        if self.app.settings.current.fxTypeVisibility[plugin.fx_type] then
            table.insert(self.assets, {
                db = self,
                type = ASSETS.PLUGIN,
                searchText = { { text = plugin.name }, { text = plugin.vendor or '' }, { text = plugin.fx_type, hide = true } },
                load = plugin.ident,
                group = plugin.group,
                vendor = plugin.vendor,
                fx_type = plugin.fx_type,
                toggleFavorite = toggleFavorite
            })
            count = count + 1
        end
    end
    for _, asset in ipairs(self.assets) do
        asset.id = asset.type .. ' ' .. asset.load
        asset.tags = self.app.tags.current.taggedAssets[asset.id] or {}
    end

    self:markFavorites()
    self:sortAssets()
    self.app.logger:logInfo('A total of ' .. count .. ' assets were added to the database')
end

DB.sortAssets = function(self)
    local groupPriority = {}
    for i, group in ipairs(self.app.settings.current.fxTypeOrder) do
        groupPriority[group] = i
    end
    groupPriority[FAVORITE_GROUP] = -4
    groupPriority[RECEIVES_GROUP] = -3
    groupPriority[TRACKS_GROUP] = -2
    groupPriority[FX_CHAINS_GROUP] = -1
    groupPriority[TRACK_TEMPLATES_GROUP] = 0

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
