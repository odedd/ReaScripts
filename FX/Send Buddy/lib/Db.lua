DB = {
    sends = {},
    track = -1, -- this is to force a track change when loading the script
    trackName = nil,
    numSends = 0,
    maxNumInserts = 0,
    changedTrack = true,
    soloedSends = {},
    plugins = {},
    tracks = {},
    init = function(self, app)
        self.plugins = {}
        self.tracks = {}
        self:getPlugins()
        self:getTracks()
        self:assembleAssets()
    end,
    sync = function(self, refresh)
        self.track, self.changedTrack = self:getSelectedTrack()
        self.refresh = refresh or false
        if self.changedTrack then
            if self.track == nil then
                self.app.setPage(APP_PAGE.NO_TRACK)
            end
            self.numSends = 0
            self.soloedSends = {}
            self.refresh = true
        end

        self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force full sync
        if self.current_project ~= self.previous_project then
            self.previous_project = self.current_project
            self.refresh = true
        end

        if self.refresh and self.track then
            _, self.trackName = reaper.GetTrackName(self.track)
            -- local _, trackName = reaper.GetTrackName(self.track)
            local oldNumSends = self.numSends
            self.numSends = reaper.GetTrackNumSends(self.track, 0)
            self.sends = {}
            self.maxNumInserts = 0
            for i = 0, self.numSends - 1 do
                local _, sendName = reaper.GetTrackSendName(self.track, i)
                local send = {
                    order = i,
                    name = sendName,
                    db = self,
                    track = self.track,
                    mute = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'B_MUTE') == 1.0,
                    vol = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'D_VOL'),
                    pan = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'D_PAN'),
                    panLaw = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'D_PANLAW'),
                    mono = math.floor(reaper.GetTrackSendInfo_Value(self.track, 0, i, 'B_MONO')),
                    polarity = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'B_PHASE') == 1.0,
                    srcChan = math.floor(reaper.GetTrackSendInfo_Value(self.track, 0, i, 'I_SRCCHAN')),
                    mode = math.floor(reaper.GetTrackSendInfo_Value(self.track, 0, i, 'I_SENDMODE')),
                    destChan = math.floor(reaper.GetTrackSendInfo_Value(self.track, 0, i, 'I_DSTCHAN')),
                    destTrack = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'P_DESTTRACK'),
                    destInserts = {},
                    destInsertsCount = 0,
                    setVolDB = function(self, dB)
                        if dB < self.db.app.settings.current.minSendVol then
                            dB = self.db.app.settings.current.minSendVol
                        elseif dB > self.db.app.settings.current.maxSendVol then
                            dB = self.db.app.settings.current.maxSendVol
                        end
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'D_VOL',
                            (dB <= self.db.app.settings.current.minSendVol and 0 or OD_ValFromdB(dB)))
                        self.db:sync(true)
                    end,
                    setPan = function(self, pan)
                        if pan < -1 then
                            pan = -1
                        elseif pan > 1 then
                            pan = 1
                        end
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'D_PAN', pan)
                        self.db:sync(true)
                    end,
                    setPanLaw = function(self, panLaw)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'D_PANLAW', panLaw)
                        self.db:sync(true)
                    end,
                    setMono = function(self, mono)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'B_MONO', mono)
                        self.db:sync(true)
                    end,
                    setPolarity = function(self, polarity)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'B_PHASE', polarity and 1 or 0)
                        self.db:sync(true)
                    end,
                    setSrcChan = function(self, srcChan)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'I_SRCCHAN', srcChan)
                        self.db:sync(true)
                    end,
                    setMode = function(self, mode)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'I_SENDMODE', mode)
                        self.db:sync(true)
                    end,
                    setDestChan = function(self, destChan)
                        local numChannels = SRC_CHANNELS[self.srcChan].numChannels +
                        (destChan >= 1024 and destChan - 1024 or destChan)
                        r.ShowConsoleMsg('numChannels: ' .. numChannels .. '\n')
                        local nearestEvenChannel = math.ceil(numChannels / 2) * 2
                        local destChanChannelCount = reaper.GetMediaTrackInfo_Value(self.destTrack, 'I_NCHAN')
                        if destChanChannelCount < numChannels then
                            reaper.SetMediaTrackInfo_Value(self.destTrack, 'I_NCHAN', nearestEvenChannel)
                        end
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'I_DSTCHAN', destChan)
                        self.db:sync(true)
                    end,
                    setMute = function(self, mute, skipRefresh)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'B_MUTE', mute and 1 or 0)
                        if not skipRefresh then self.db:sync(true) end
                    end,
                    setSolo = function(self, solo, exclusive)
                        local exclusive = (exclusive ~= false) and true or false
                        if exclusive then self.db.soloedSends = {} end
                        if solo then
                            self.db.soloedSends[i] = true
                        else
                            self.db.soloedSends[i] = nil
                        end
                        -- reaper.ShowConsoleMsg('soloedSends: ' .. tostring(self.sends) .. '\n')
                        for si, send in ipairs(self.db.sends) do
                            -- reaper.ShowConsoleMsg(snd.name .. '\n')
                            if next(self.db.soloedSends) == nil then
                                send:setMute(false, true)
                            else
                                send:setMute(exclusive and (si == i) or (self.db.soloedSends[si - 1] == nil), true)
                            end
                        end
                        self.db:sync(true)
                    end,
                    addInsert = function(self, fxName)
                        local fxIndex = r.TrackFX_AddByName(self.destTrack, fxName, false, -1)
                        if fxIndex == -1 then
                            self.db.app.logger:logError('Cannot add ' .. fxName .. ' to ' .. self.destTrack)
                            return false
                        end
                        self.db:sync(true)
                        return true
                    end,
                }
                send.destInsertsCount = r.TrackFX_GetCount(send.destTrack)
                -- local maxW = (app.gui.TEXT_BASE_HEIGHT*fxCount<=h) and (app.settings.current.sendWidth) or (app.settings.current.sendWidth - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize()))
                send.destInserts, send.destInsertsCount = self:getInserts(send.destTrack)
                if send.destInsertsCount > self.maxNumInserts then
                    self.maxNumInserts = send.destInsertsCount
                end

                table.insert(self.sends, send)
            end
           
            if self.numSends == 0 then
                self.app.setPage(APP_PAGE.NO_SENDS)
            else
                self.app.setPage(APP_PAGE.MIXER)
            end
            if oldNumSends ~= self.numSends then
                 self.app.refreshWindowSizeOnNextFrame = true
            end
        end
    end
}

--- Sends

DB.createNewSend = function(self, asset)
    if asset.type == ASSETS.TRACK then
        -- local sendTrackIndex = asset.load
        local sendTrack = OD_GetTrackFromGuid(0, asset.load)
        if sendTrack then
            reaper.CreateTrackSend(self.track, sendTrack)
        end
    elseif asset.type == ASSETS.PLUGIN then
        local newTrackIndex = r.GetNumTracks()
        reaper.InsertTrackAtIndex(newTrackIndex, true)
        local newTrack = reaper.GetTrack(0, newTrackIndex)
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", asset.name, true)
        reaper.CreateTrackSend(self.track, newTrack)
        self:sync(true)
        for _, send in ipairs(self.sends) do
            if send.destTrack == newTrack then
                send:addInsert(asset.load)
            end
        end
    end
    self:sync(true)
end


--- TRACKS
DB.getSelectedTrack = function(self)
    if self.app.settings.current.followSelectedTrack == false and self.track ~= nil and self.track ~= -1 then return self.track, false end
    local track = reaper.GetLastTouchedTrack()
    if track == nil and self.track ~= nil then
        self.trackName = nil
        self.sends = {}
        return nil, true
    end
    return track, (track ~= self.track)
end

-- get project tracks into self.tracks, keeping the track's GUID, name and color, and wheather it has receives or not
DB.getTracks = function(self)
    self:sync()
    self.tracks = {}
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local skip = false
        for _, send in ipairs(self.sends) do
            if send.destTrack == track then
                skip = true
            end
        end
        if not skip then
            local trackName = select(2, reaper.GetTrackName(track))
            local trackColor = reaper.GetTrackColor(track)
            local trackGuid = reaper.GetTrackGUID(track)
            local hasReceives = reaper.GetTrackNumSends(track, -1) > 0
            table.insert(self.tracks, {
                name = trackName,
                guid = trackGuid,
                color = trackColor,
                hasReceives = hasReceives,
                order = i,
            })
        end
    end
end


--- INSERTS
DB.getInserts = function(self, track)
    local fxCount = r.TrackFX_GetCount(track)
    local inserts = {}
    for i = 0, fxCount - 1 do
        local _, fxName = r.TrackFX_GetFXName(track, i, '')
        local offline = r.TrackFX_GetOffline(track, i)
        local enabled = r.TrackFX_GetEnabled(track, i)
        local shortName, shortened = self.app.minimizeText(fxName:gsub('.-%:', ''):gsub('%(.-%)$', ''),
            self.app.settings.current.sendWidth -
            r.ImGui_GetStyleVar(self.app.gui.ctx, r.ImGui_StyleVar_FramePadding()) * 2)
        table.insert(inserts, {
            order = i,  
            db = self,
            name = fxName,
            shortName = shortName,
            shortened = shortened,
            offline = offline,
            enabled = enabled,
            track = track,
            setEnabled = function(self, enabled)
                r.TrackFX_SetEnabled(self.track, i, enabled)
                self.db:sync(true)
            end,
            setOffline = function(self, offline)
                r.TrackFX_SetOffline(self.track, i, offline)
                self.db:sync(true)
            end,
            delete = function(self)
                r.TrackFX_Delete(self.track, i)
                self.db:sync(true)
            end,
            toggleShow = function(self)
                if not r.TrackFX_GetOpen(track, i) then
                    r.TrackFX_Show(track, i, 3)
                    return true
                else
                    r.TrackFX_Show(track, i, 2)
                    return false
                end
            end
        })
    end
    return inserts, fxCount
end


--- PLUGINS
DB.addPlugin = function(self, full_name, fx_type, instrument, ident)
    -- TODO: check about all plugin types
    self.app.logger:logDebug('-- OD_VPS_DB:addPlugin()')
    local self = self

    local function extractNameVendor(full_name, fx_type)
        self.app.logger:logDebug('-- OD_VPS_DB:addPlugin() -> extractNameVendor()')
        local name, vendor
        local t = {}

        name = (fx_type == 'Internal') and full_name or full_name:match(fx_type .. ': (.+)$')
        if not fx_type:match('^JS') and fx_type ~= 'Internal' and fx_type ~= 'ReWire' then
            -- fx_type:match('^VST') then
            local counter = 1
            for w in string.gmatch(full_name, "%b()") do
                t[counter] = w:match("%((.+)%)")
                counter = counter + 1
            end
        end
        vendor = t[#t]

        if vendor == nil and name == nil and (#t == 0) then return false end
        if not fx_type:match('^JS') then
            if next(t) ~= nil and (t[#t]:match('.-%dch$') or t[#t]:match('%d*%sout$') or t[#t] == 'mono') then
                vendor = t[#t - 1]
            end
            if fx_type ~= 'Internal' and fx_type ~= 'ReWire' then
                name = vendor and name:gsub(' %(' .. OD_EscapePattern(vendor) .. '%).-$', '') or name
            end
        end
        return true, name, (vendor == '' and nil or vendor)
    end

    if full_name == '' then return false end

    local success, name, vendor = extractNameVendor(full_name, fx_type)

    if not success then
        self.app.logger:logError('cannot parse plugin name: ' .. full_name)
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
    self.app.logger:logInfo('Added ' ..
        fx_type .. (instrument and 'i' or '') .. ': ' .. name .. (vendor and (' by ' .. vendor) or ''),
        full_name)
    return plugin
end
DB.getPlugins = function(self)
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
            plugin.group = OD_HasValue(self.app.settings.current.favorites, plugin.full_name) and FAVORITE_GROUP or
                plugin.fx_type
        end
        i = i + 1
        if not found then break end
    end
end

-- ASSETS

DB.assembleAssets = function(self)
    self.assets = {}
    for _, track in ipairs(self.tracks) do
        table.insert(self.assets, {
            type = ASSETS.TRACK,
            name = track.name,
            load = track.guid,
            group = track.hasReceives and RECEIVES_GROUP or TRACKS_GROUP,
            order = track.order,
            color = track.color
        })
    end
    for _, plugin in ipairs(self.plugins) do
        table.insert(self.assets, {
            type = ASSETS.PLUGIN,
            name = plugin.name,
            load = plugin.full_name,
            group = plugin.group,
            vendor = plugin.vendor,
            fx_type = plugin.fx_type
        })
    end

    self:sortAssets()
end

DB.sortAssets = function(self)
    local groupPriority = OD_DeepCopy(self.app.settings.current.groupPriority)
    groupPriority[RECEIVES_GROUP] = -2
    groupPriority[TRACKS_GROUP] = -1
    groupPriority[FAVORITE_GROUP] = 0
    table.sort(self.assets, function(a, b)
        local aPriority = groupPriority[a.group] or 100
        local bPriority = groupPriority[b.group] or 100
        if a.type == ASSETS['TRACK'] and b.type == ASSETS['TRACK'] and aPriority == bPriority then
            return a.order < b.order
        elseif aPriority == bPriority then
            return a.name < b.name
        else
            return aPriority < bPriority
        end
    end)
end
