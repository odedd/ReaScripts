DB = {
    sends = {},
    track = -1, -- this is to force a track change when loading the script
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
    save = function(self)
        -- persist track states
        for trackIdx = 0, r.CountTracks(0) - 1 do
            local rTrack = r.GetTrack(0, trackIdx)
            local foundTrackInfo = {}
            if self.tracks then
                for i, track in ipairs(self.tracks) do
                    if rTrack == track.object then
                        foundTrackInfo = track
                    end
                end
            end
            if foundTrackInfo.soloMatrix and not (foundTrackInfo.soloMatrix == 0) then
                local retval = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_SOLO_MATRIX',
                    pickle(foundTrackInfo.soloMatrix), true)
            else
                r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_SOLO_MATRIX', '', true)
            end
            if foundTrackInfo.origMuteMatrix and not (foundTrackInfo.origMuteMatrix == 0) then
                local retval = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_ORIG_MUTE_MATRIX',
                    pickle(foundTrackInfo.origMuteMatrix), true)
            else
                r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_ORIG_MUTE_MATRIX', '', true)
            end
        end
        -- for k, v in pairs(self.savedSoloStates) do
        --     r.SetProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', k, pickle(v))
        -- end
        r.MarkProjectDirty(0)
    end,
    sync = function(self, refresh)
        self.track, self.changedTrack = self:getSelectedTrack()
        self.refresh = refresh or false
        if self.changedTrack then
            if self.track.object == nil then
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

        if self.refresh and self.track.object then
            -- load savedSoloStates
            self.savedSoloStates = {}
            local i = 0
            -- local retval, k, v = r.EnumProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', i)
            -- while retval do
            --     self.savedSoloStates[k] = unpickle(v)
            --     i = i + 1
            --     retval, k, v = r.EnumProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', i)
            -- end
            -- self.savedSoloStates = self.savedSoloStates or {}

            local oldNumSends = self.numSends
            self.numSends = reaper.GetTrackNumSends(self.track.object, 0)
            self.sends = {}
            self.maxNumInserts = 0
            for i = 0, self.numSends - 1 do
                local _, sendName = reaper.GetTrackSendName(self.track.object, i)
                local midiRouting = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'I_MIDIFLAGS'))
                local send = {
                    order = i,
                    name = sendName,
                    db = self,
                    track = self.track,
                    mute = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'B_MUTE') == 1.0,
                    vol = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'D_VOL'),
                    pan = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'D_PAN'),
                    panLaw = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'D_PANLAW'),
                    mono = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'B_MONO')),
                    polarity = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'B_PHASE') == 1.0,
                    srcChan = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'I_SRCCHAN')),
                    mode = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'I_SENDMODE')),
                    midiSrcChn = midiRouting & 0x1f,
                    midiSrcBus = midiRouting >> 14 & 0xff,
                    midiDestChn = midiRouting >> 5 & 0x1f,
                    midiDestBus = midiRouting >> 22 & 0xff,
                    destChan = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'I_DSTCHAN')),
                    destTrack = self:getTrack(reaper.GetTrackSendInfo_Value(self.track.object, 0, i, 'P_DESTTRACK')),
                    destInserts = {},
                    destInsertsCount = 0,
                    delete = function(self) -- TODO: reflect removed send in solo states
                        reaper.RemoveTrackSend(self.track.object, 0, self.order)
                        self.db:sync(true)
                    end,
                    setVolDB = function(self, dB)
                        if dB < self.db.app.settings.current.minSendVol then
                            dB = self.db.app.settings.current.minSendVol
                        elseif dB > self.db.app.settings.current.maxSendVol then
                            dB = self.db.app.settings.current.maxSendVol
                        end
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'D_VOL',
                            (dB <= self.db.app.settings.current.minSendVol and 0 or OD_ValFromdB(dB)))
                        self.db:sync(true)
                    end,
                    setPan = function(self, pan)
                        if pan < -1 then
                            pan = -1
                        elseif pan > 1 then
                            pan = 1
                        end
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'D_PAN', pan)
                        self.db:sync(true)
                    end,
                    setPanLaw = function(self, panLaw)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'D_PANLAW', panLaw)
                        self.db:sync(true)
                    end,
                    setMono = function(self, mono)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'B_MONO', mono)
                        self.db:sync(true)
                    end,
                    setPolarity = function(self, polarity)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'B_PHASE', polarity and 1 or 0)
                        self.db:sync(true)
                    end,
                    setSrcChan = function(self, srcChan)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'I_SRCCHAN', srcChan)
                        self.db:sync(true)
                    end,
                    setMidiRouting = function(self, srcChn, srcBus, destChn, destBus)
                        srcChn = srcChn or self.midiSrcChn
                        srcBus = srcBus or self.midiSrcBus
                        destChn = destChn or self.midiDestChn
                        destBus = destBus or self.midiDestBus
                        local midiRouting = srcChn + (srcBus << 14) | (destChn) << 5 | (destBus << 22)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'I_MIDIFLAGS', midiRouting)
                        self.db:sync(true)
                    end,
                    setMode = function(self, mode)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'I_SENDMODE', mode)
                        self.db:sync(true)
                    end,
                    setDestChan = function(self, destChan)
                        local numChannels = SRC_CHANNELS[self.srcChan].numChannels +
                            (destChan >= 1024 and destChan - 1024 or destChan)
                        local nearestEvenChannel = math.ceil(numChannels / 2) * 2
                        local destChanChannelCount = reaper.GetMediaTrackInfo_Value(self.destTrack.object, 'I_NCHAN')
                        if destChanChannelCount < numChannels then
                            reaper.SetMediaTrackInfo_Value(self.destTrack.object, 'I_NCHAN', nearestEvenChannel)
                        end
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'I_DSTCHAN', destChan)
                        self.db:sync(true)
                    end,
                    setMute = function(self, mute, skipRefresh)
                        reaper.SetTrackSendInfo_Value(self.track.object, 0, self.order, 'B_MUTE', mute and 1 or 0)
                        if not skipRefresh then self.db:sync(true) end
                    end,
                    _getSoloMatrix = function(self)
                        local counter = 0
                        for i, send in ipairs(self.db.sends) do
                            if send.order == self.order then break end
                            if send.destTrack == self.destTrack then
                                counter = counter + 1
                            end
                        end
                        if self.destTrack.soloMatrix[self.track.guid] == nil then
                            self.destTrack.soloMatrix[self.track.guid] = {}
                        end
                        return self.destTrack.soloMatrix[self.track.guid], counter
                    end,
                    sayHi = function(self)
                        return 'hi'
                    end,
                    _getOrigMuteState = function(self)
                        local counter = 0
                        for i, send in ipairs(self.db.sends) do
                            if send.order == self.order then break end
                            if send.destTrack == self.destTrack then
                                counter = counter + 1
                            end
                        end
                        if self.destTrack.origMuteMatrix[self.track.guid] == nil then
                            self.destTrack.origMuteMatrix[self.track.guid] = {}
                        end
                        return self.destTrack.origMuteMatrix[self.track.guid][counter] or false
                    end,
                    getSolo = function(self)
                        -- self.destTrack.soloMatrix[self.track.guid] = {}
                        local sm, counter = self:_getSoloMatrix()
                        return sm[counter] or SOLO_STATES.NONE
                    end,
                    setSolo = function(self, solo, exclusive)
                        -- deafult to true if solo == SOLO_STATES.SOLO
                        local exclusive = (exclusive ~= false) and (solo == SOLO_STATES.SOLO) or false
                        self:_saveOrigMuteState()
                        local sm, counter = self:_getSoloMatrix()
                        local prevDeskTrack = nil
                        -- turn off all solos if exclusive == true
                        local j = 0
                        for i, send in ipairs(self.db.sends) do
                            if send.destTrack == prevDeskTrack then
                                j = j + 1
                            else
                                j = 0
                            end
                            if exclusive and (send ~= self) then
                                local sm, j = send:_getSoloMatrix()
                                if sm[j] == SOLO_STATES.SOLO then
                                    sm[j] = SOLO_STATES.NONE
                                end
                            end
                            prevDeskTrack = send.destTrack
                        end
                        sm[counter] = solo

                        self:_reflectSolos(true)
                        self.db:save()
                    end,
                    _numSolos = function(self)
                        local numOfSolos = 0
                        for i, send in ipairs(self.db.sends) do
                            local sm, j = send:_getSoloMatrix()
                            if sm[j] == SOLO_STATES.SOLO then
                                numOfSolos = numOfSolos + 1
                            end
                        end
                        return numOfSolos
                    end,
                    _saveOrigMuteState = function(self)
                        local numOfSolos = self:_numSolos()
                        local prevDeskTrack = nil
                        local j = 0
                        for i, send in ipairs(self.db.sends) do
                            if send.destTrack == prevDeskTrack then
                                j = j + 1
                            else
                                j = 0
                            end
                            if numOfSolos == 0 then
                                send.destTrack.origMuteMatrix[self.track.guid] = send.destTrack.origMuteMatrix
                                    [self.track.guid] or {}
                                send.destTrack.origMuteMatrix[self.track.guid][j] = send.mute
                            end
                            prevDeskTrack = send.destTrack
                        end
                    end,
                    _reflectSolos = function(self, resetIfNeeded)
                        local numSolos = self:_numSolos()
                        if numSolos > 0 then
                            for j, send in ipairs(self.db.sends) do
                                send:setMute(send:getSolo() == SOLO_STATES.NONE)
                            end
                        end
                        if resetIfNeeded and numSolos == 0 then
                            for j, send in ipairs(self.db.sends) do
                                send:setMute(send:_getOrigMuteState())
                            end
                        end
                    end,
                    addInsert = function(self, fxName)
                        local fxIndex = r.TrackFX_AddByName(self.destTrack.object, fxName, false, -1)
                        if fxIndex == -1 then
                            self.db.app.logger:logError('Cannot add ' .. fxName .. ' to ' .. self.destTrack.object)
                            return false
                        end
                        self.db:sync(true)
                        return true
                    end,
                    toggleVolEnv = function(self, show)
                        local env = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, "P_ENV:<VOLENV")
                        OD_ToggleShowEnvelope(env, show)
                    end,
                    togglePanEnv = function(self, show)
                        local env = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, "P_ENV:<PANENV")
                        OD_ToggleShowEnvelope(env, show)
                    end,
                    toggleMuteEnv = function(self, show)
                        local env = reaper.GetTrackSendInfo_Value(self.track.object, 0, i, "P_ENV:<MUTEENV")
                        OD_ToggleShowEnvelope(env, show)
                    end,
                }
                send.destInsertsCount = r.TrackFX_GetCount(send.destTrack.object)
                -- local maxW = (app.gui.TEXT_BASE_HEIGHT*fxCount<=h) and (app.settings.current.sendWidth) or (app.settings.current.sendWidth - r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize()))
                send.destInserts, send.destInsertsCount = self:getInserts(send.destTrack.object)
                if send.destInsertsCount > self.maxNumInserts then
                    self.maxNumInserts = send.destInsertsCount
                end

                table.insert(self.sends, send)
            end

            self.app.setPage(APP_PAGE.MIXER)
            if oldNumSends ~= self.numSends then
                self.app.refreshWindowSizeOnNextFrame = true
            end
        end
    end
}

--- Sends

DB.createNewSend = function(self, asset, trackName) -- TODO: reflect added send in solo states
    if asset.type == ASSETS.TRACK then
        -- local sendTrackIndex = asset.load
        local sendTrack = OD_GetTrackFromGuid(0, asset.load)
        if sendTrack then
            reaper.CreateTrackSend(self.track.object, sendTrack)
        end
    elseif asset.type == ASSETS.PLUGIN then
        local newTrackIndex = r.GetNumTracks()
        reaper.InsertTrackAtIndex(newTrackIndex, true)
        local newTrack = reaper.GetTrack(0, newTrackIndex)
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", trackName, true)
        reaper.CreateTrackSend(self.track.object, newTrack)
        self:sync(true)
        for _, send in ipairs(self.sends) do
            if send.destTrack.object == newTrack then
                send:addInsert(asset.load)
            end
        end
    end
    self:sync(true)
end


--- TRACKS
DB.getSelectedTrack = function(self)
    if self.app.settings.current.followSelectedTrack == false and self.track ~= nil and self.track.object ~= nil and self.track ~= -1 then
        return
            self.track, false
    end
    local track = reaper.GetLastTouchedTrack()
    if track == nil and self.track ~= nil then
        self.trackName = nil
        self.sends = {}
        return { object = nil }, true
    end
    for i, trk in ipairs(self.tracks) do
        if track == trk.object then
            return trk, (trk ~= self.track)
        end
    end
    -- if not found, refresh tracks and try again
    self:getTracks()
    return self:getSelectedTrack()
end

-- get project tracks into self.tracks, keeping the track's GUID, name and color, and wheather it has receives or not
DB.getTracks = function(self)
    -- self:sync()
    self.tracks = {}
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        -- if track ~= self.track then
        local trackName = select(2, reaper.GetTrackName(track))
        local trackColor = reaper.GetTrackColor(track)
        local trackGuid = reaper.GetTrackGUID(track)
        local hasReceives = reaper.GetTrackNumSends(track, -1) > 0
        local _, rawSsoloMatrix = r.GetSetMediaTrackInfo_String(track, "P_EXT:" .. Scr.ext_name ..
            '_SOLO_MATRIX', "", false)
        local _, rawOrigMuteMatrix = r.GetSetMediaTrackInfo_String(track, "P_EXT:" .. Scr.ext_name ..
            '_ORIG_MUTE_MATRIX', "", false)
        local soloMatrix = rawSsoloMatrix and unpickle(rawSsoloMatrix) or {}
        local origMuteMatrix = rawOrigMuteMatrix and unpickle(rawOrigMuteMatrix) or {}
        table.insert(self.tracks, {
            object = track,
            name = trackName,
            guid = trackGuid,
            color = trackColor,
            hasReceives = hasReceives,
            soloMatrix = soloMatrix,
            origMuteMatrix = origMuteMatrix,
            order = i,
        })
        -- end
    end
end


--- SOLOS

DB.saveSoloState = -- save current projects solo state to a temporary variable,
-- for use after unsoloing sends
    function(self)
        -- self.savedSoloStates = {}
        -- for i = 0, r.CountTracks(0) - 1 do
        --     local track = r.GetTrack(0, i)
        --     self.savedSoloStates[r.GetTrackGUID(track)] = {
        --         ['solo'] = r.GetMediaTrackInfo_Value(track, 'I_SOLO'),
        --         ['mute'] = r.GetMediaTrackInfo_Value(track, 'B_MUTE')
        --     }
        -- end
        self:save()
    end
DB.recallSoloState = function(self)
    for i = 0, r.CountTracks(0) - 1 do
        local track = r.GetTrack(0, i)
        local trackGUID = r.GetTrackGUID(track)
        local savedState = self.savedSoloStates[trackGUID]
        if savedState then
            if r.GetMediaTrackInfo_Value(track, 'I_SOLO') ~= savedState.solo then
                r.SetMediaTrackInfo_Value(track, 'I_SOLO', savedState.solo)
            end
            if r.GetMediaTrackInfo_Value(track, 'B_MUTE') ~= savedState.mute then
                r.SetMediaTrackInfo_Value(track, 'B_MUTE', savedState.mute)
            end
        end
    end
end
DB.getTrack = function(self, track)
    for i, trk in ipairs(self.tracks) do
        if track == trk.object then
            return trk
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
                if not r.TrackFX_GetOpen(self.track, i) then
                    r.TrackFX_Show(self.track, i, 3)
                    return true
                else
                    r.TrackFX_Show(self.track, i, 2)
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
            searchText = { { text = track.name } },
            load = track.guid,
            group = track.hasReceives and RECEIVES_GROUP or TRACKS_GROUP,
            order = track.order,
            color = track.color
        })
    end
    for _, plugin in ipairs(self.plugins) do
        table.insert(self.assets, {
            type = ASSETS.PLUGIN,
            searchText = { { text = plugin.name }, { text = plugin.vendor or '' }, { text = plugin.fx_type, hide = true } },
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
            return a.searchText[1].text < b.searchText[1].text
        else
            return aPriority < bPriority
        end
    end)
end
