DB = {
    sends = {},
    track = nil,
    trackName = nil,
    numSends = 0,
    maxNumInserts = 0,
    changedTrack = true,
    soloedSends = {},
    plugins = {},
    init = function(self, app)
        self:getPlugins()
    end,
    getSelectedTrack = function(self)
        if self.app.settings.current.autoSelectTrack == false and self.track ~= nil then return self.track, false end
        if reaper.CountSelectedTracks(0) == 0 then
            if self.track ~= nil then
                -- self.app.logger:logDebug('No tracks selected. Zeroing sends.')
                self.trackName = nil
                self.sends = {}
            end
            return nil, false
        end
        -- check for self.track==nil because on first script run the GetCursorContext() does not return 0
        if r.GetCursorContext() == 0 or self.track == nil then
            local track = reaper.GetLastTouchedTrack()
            return track, track ~= self.track
        end
    end,
    getInserts = function(self, track)
        local fxCount = r.TrackFX_GetCount(track)
        local inserts = {}
        for i = 0, fxCount - 1 do
            local _, fxName = r.TrackFX_GetFXName(track, i, '')
            local offline = r.TrackFX_GetOffline(track, i)
            local enabled = r.TrackFX_GetEnabled(track, i)
            local shortName, shortened = self.app.minimizeText(fxName:gsub('.-%:', ''):gsub('%(.-%)$', ''),
                self.app.settings.current.sendWidth - r.ImGui_GetStyleVar(self.app.gui.ctx, r.ImGui_StyleVar_FramePadding()) * 2)
            table.insert(inserts, {
                order = i,
                name = fxName,
                shortName = shortName,
                shortened = shortened,
                offline = offline,
                enabled = enabled,
                track = track,
                setEnabled = function(self, enabled)
                    r.TrackFX_SetEnabled(self.track, i, enabled)
                end,
                setOffline = function(self, offline)
                    r.TrackFX_SetOffline(self.track, i, offline)
                end,
                delete = function(self)
                    r.TrackFX_Delete(self.track, i)
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
    end,
    sync = function(self)
        self.track, self.changedTrack = self:getSelectedTrack()
        if self.changedTrack then
            self.soloedSends = {}
        end
        if self.track then
            _, self.trackName = reaper.GetTrackName(self.track)
            local _, trackName = reaper.GetTrackName(self.track)
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
                    mute = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'B_MUTE'),
                    vol = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'D_VOL'),
                    pan = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'D_PAN'),
                    panLaw = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'D_PANLAW'),
                    mono = math.floor(reaper.GetTrackSendInfo_Value(self.track, 0, i, 'B_MONO')),
                    phase = reaper.GetTrackSendInfo_Value(self.track, 0, i, 'B_PHASE'),
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
                    end,
                    setPan = function(self, pan)
                        if pan < -1 then
                            pan = -1
                        elseif pan > 1 then
                            pan = 1
                        end
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'D_PAN', pan)
                    end,
                    setPanLaw = function(self, panLaw)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'D_PANLAW', panLaw)
                    end,
                    setMono = function(self, mono)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'B_MONO', mono)
                    end,
                    setPhase = function(self, phase)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'B_PHASE', phase)
                    end,
                    setSrcChan = function(self, srcChan)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'I_SRCCHAN', srcChan)
                    end,
                    setMode = function(self, mode)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'I_SENDMODE', mode)
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
                    end,
                    setMute = function(self, mute)
                        reaper.SetTrackSendInfo_Value(self.track, 0, self.order, 'B_MUTE', mute and 1 or 0)
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
                                send:setMute(false)
                            else
                                send:setMute(exclusive and (si == i) or (self.db.soloedSends[si - 1] == nil))
                            end
                        end
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
        end
    end
}

DB.addPlugin = function(self, full_name, fx_type, instrument, ident)
    -- TODO: check about DX and DXi plugins (maybe in windows?)
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
            plugin.group = OD_HasValue(self.app.settings.current.favorites, plugin.full_name) and FAVORITE_GROUP or plugin.fx_type
        end
        i = i + 1
        if not found then break end
    end
    self:sortPlugins()
end
DB.sortPlugins = function(self)
    local groupPriority = OD_DeepCopy(self.app.settings.current.groupPriority)
    groupPriority[FAVORITE_GROUP] = 0
    table.sort(self.plugins, function(a, b)
        local aPriority = groupPriority[a.group] or 100
        local bPriority = groupPriority[b.group] or 100
        if aPriority == bPriority then
            return a.name < b.name
        else
            return aPriority < bPriority
        end
    end)
end