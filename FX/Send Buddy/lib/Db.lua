DB = {
    sends = {},
    track = -1, -- this is to force a track change when loading the script
    numSends = { [SEND_TYPE.SEND] = 0, [SEND_TYPE.RECV] = 0, [SEND_TYPE.HW] = 0 },
    totalSends = 0,
    maxNumInserts = 0,
    changedTrack = true,
    soloedSends = {},
    plugins = {},
    tracks = {},
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
        self.plugins = {}
        self.tracks = {}
        self.masterTrack = reaper.GetMasterTrack(0)
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
            local retval = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_MASTER_SEND_STATE',
                foundTrackInfo.masterSendState and '1' or '', true)
            local retval = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_SEND_LISTEN',
                foundTrackInfo.sendListen and (foundTrackInfo.sendListen .. ' ' .. foundTrackInfo.sendListenMode) or '',
                true)
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
        r.MarkProjectDirty(0)
    end,
    sync = function(self, refresh)
        self.track, self.changedTrack = self:getSelectedTrack()
        self.refresh = refresh or false
        if self.changedTrack then
            if self.track.object == nil then
                self.app.setPage(APP_PAGE.NO_TRACK)
            end
            self.numSends = { [SEND_TYPE.SEND] = 0, [SEND_TYPE.RECV] = 0, [SEND_TYPE.HW] = 0 }
            self.totalSends = 0
            self.soloedSends = {}
            self.refresh = true
        end

        self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force full sync
        if self.current_project ~= self.previous_project then
            self:getTracks()
            self.previous_project = self.current_project
            self.refresh = true
        end

        if self.refresh and self.track.object then
            -- load savedSoloStates
            -- self.savedSoloStates = {}
            -- local i = 0
            -- local retval, k, v = r.EnumProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', i)
            -- while retval do
            --     self.savedSoloStates[k] = unpickle(v)
            --     i = i + 1
            --     retval, k, v = r.EnumProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', i)
            -- end
            -- self.savedSoloStates = self.savedSoloStates or {}
            local existingTargetGuidCount = {}
            local oldNumSends = {}
            self.totalSends = 0
            self.maxNumInserts = 0
            self.sends = {}
            self.guids = {}
            self.numAudioOutputs = r.GetNumAudioOutputs()
            local numHWSends = reaper.GetTrackNumSends(self.track.object, 1)
            local overallOrder = 0
            for _, type in pairs(SEND_TYPE) do
                oldNumSends[type] = self.numSends[type]
                self.numSends[type] = reaper.GetTrackNumSends(self.track.object, type)
                self.totalSends = self.totalSends + self.numSends[type]
                for i = 0, self.numSends[type] - 1 do
                    local sendName
                    if type == SEND_TYPE.SEND then
                        _, sendName = reaper.GetTrackSendName(self.track.object, i + numHWSends)
                    elseif type == SEND_TYPE.RECV then
                        _, sendName = reaper.GetTrackReceiveName(self.track.object, i)
                    end
                    local midiRouting = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, type, i,
                        'I_MIDIFLAGS'))
                    local send = {
                        type = type,
                        order = overallOrder,
                        index = i,
                        name = sendName,
                        db = self,
                        track = self.track,
                        mute = reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'B_MUTE') == 1.0,
                        vol = reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'D_VOL'),
                        pan = reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'D_PAN'),
                        panLaw = reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'D_PANLAW'),
                        mono = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'B_MONO')),
                        polarity = reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'B_PHASE') == 1.0,
                        srcChan = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'I_SRCCHAN')),
                        mode = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'I_SENDMODE')),
                        midiSrcChn = midiRouting & 0x1f,
                        midiSrcBus = midiRouting >> 14 & 0xff,
                        midiDestChn = midiRouting >> 5 & 0x1f,
                        midiDestBus = midiRouting >> 22 & 0xff,
                        destChan = math.floor(reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'I_DSTCHAN')),
                        destTrack = (type ~= SEND_TYPE.HW) and
                            self:_getTrack(reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'P_DESTTRACK')) or
                            nil,
                        srcTrack = (type ~= SEND_TYPE.HW) and
                            self:_getTrack(reaper.GetTrackSendInfo_Value(self.track.object, type, i, 'P_SRCTRACK')) or
                            nil,
                        destInserts = {},
                        destInsertsCount = 0,
                        delete = function(self)
                            self.db:beginUndoBlock()
                            reaper.RemoveTrackSend(self.track.object, self.type, self.index)
                            -- Updates the GUIDs in the database after a send has been deleted,
                            -- and updates the soloMatrix and sendListen states accordingly
                            local deletedBaseGuid, deletedGuidIndex = self.guid:match('(.*)_(%d-)$')
                            self.db.lastGuids = {}
                            for _, send in ipairs(self.db.sends) do
                                local baseGuid, guidIndex = send.guid:match('(.*)_(%d-)$')
                                if baseGuid == deletedBaseGuid and tonumber(guidIndex) > tonumber(deletedGuidIndex) then
                                    local newGuid = baseGuid .. '_' .. (tonumber(guidIndex) - 1)
                                    send.track.soloMatrix[newGuid] = send.track.soloMatrix[send.guid]
                                    if send.track.sendListen == newGuid then
                                        send.track.sendListen = send.guid
                                    end
                                    send.guid = newGuid
                                end
                                if send.guid ~= self.guid then
                                    table.insert(self.db.lastGuids, send.guid)
                                end
                            end
                            self.db:sync(true)
                            self.db:endUndoBlock('Delete send', 1)
                        end,
                        setVolDB = function(self, dB) -- because of the complexity of the input mechanism, undo states are handled in the GUI
                            if dB < self.db.app.settings.current.minSendVol then
                                dB = self.db.app.settings.current.minSendVol
                            elseif dB > self.db.app.settings.current.maxSendVol then
                                dB = self.db.app.settings.current.maxSendVol
                            end
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'D_VOL',
                                (dB <= self.db.app.settings.current.minSendVol and 0 or OD_ValFromdB(dB)))
                            self.db:sync(true)
                        end,
                        setPan = function(self, pan) -- because of the complexity of the input mechanism, undo states are handled in the GUI
                            if pan < -1 then
                                pan = -1
                            elseif pan > 1 then
                                pan = 1
                            end
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'D_PAN', pan)
                            self.db:sync(true)
                        end,
                        setPanLaw = function(self, panLaw) -- TODO implement!
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'D_PANLAW', panLaw)
                            self.db:sync(true)
                            self.db:setUndoPoint('Change send pan law', 1)
                        end,
                        setMono = function(self, mono) -- TODO implement!
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'B_MONO', mono)
                            self.db:sync(true)
                            self.db:setUndoPoint('Toggle send mono mixdown', 1)
                        end,
                        setPolarity = function(self, polarity)
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'B_PHASE',
                                polarity and 1 or 0)
                            self.db:sync(true)
                            self.db:setUndoPoint('Toggle send polarity', 1)
                        end,
                        setSrcChan = function(self, srcChan)
                            local targetTrack = (self.type == SEND_TYPE.HW) and self.track or self.srcTrack
                            local numChannels = SRC_CHANNELS[srcChan].numChannels +
                            (srcChan >= 1024 and math.fmod(srcChan, 512) or srcChan)
                            local nearestEvenChannel = math.ceil(numChannels / 2) * 2
                            local srcChanChannelCount = targetTrack.numChannels
                            if srcChanChannelCount < numChannels then
                                reaper.SetMediaTrackInfo_Value(targetTrack.object, 'I_NCHAN', nearestEvenChannel)
                            end
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'I_SRCCHAN', srcChan)
                            self.db:sync(true)
                            self.db:setUndoPoint('Change source channel', 1)
                        end,
                        setMidiRouting = function(self, srcChn, srcBus, destChn, destBus)
                            srcChn = srcChn or self.midiSrcChn
                            srcBus = srcBus or self.midiSrcBus
                            destChn = destChn or self.midiDestChn
                            destBus = destBus or self.midiDestBus
                            local midiRouting = srcChn + (srcBus << 14) | (destChn) << 5 | (destBus << 22)
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'I_MIDIFLAGS',
                                midiRouting)
                            self.db:sync(true)
                            self.db:setUndoPoint('Set send midi routing', 1)
                        end,
                        setMode = function(self, mode)
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'I_SENDMODE', mode)
                            self.db:sync(true)
                            self.db:setUndoPoint('Set send mode', 1)
                        end,
                        setDestChan = function(self, destChan)
                            if self.type == SEND_TYPE.HW then 
                                reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'I_DSTCHAN', destChan)
                                self.db:sync(true)
                                return
                            end
                            local numChannels = SRC_CHANNELS[self.srcChan].numChannels +
                                (destChan >= 1024 and destChan - 1024 or destChan)
                            local nearestEvenChannel = math.ceil(numChannels / 2) * 2
                            local destChanChannelCount = self.destTrack.numChannels
                            if destChanChannelCount < numChannels then
                                reaper.SetMediaTrackInfo_Value(self.destTrack.object, 'I_NCHAN', nearestEvenChannel)
                            end
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'I_DSTCHAN', destChan)
                            self.db:sync(true)
                            self.db:setUndoPoint('Change destination channel', 1)
                        end,
                        setMute = function(self, mute, skipRefresh)
                            reaper.SetTrackSendInfo_Value(self.track.object, self.type, self.index, 'B_MUTE',
                                mute and 1 or 0)
                            if not skipRefresh then self.db:sync(true) end
                            self.db:setUndoPoint('Mute send', 1)
                        end,
                        getSolo = function(self)
                            return self.track.soloMatrix[self.guid] or SOLO_STATES.NONE
                        end,
                        goToDestTrack = function(self) -- selecting tracks does not create undo points
                            if self.type == SEND_TYPE.HW then return end
                            local target = (self.type == SEND_TYPE.SEND) and self.destTrack or self.srcTrack
                            r.SetMediaTrackInfo_Value(target.object, 'B_SHOWINMIXER', 1)
                            r.SetMediaTrackInfo_Value(target.object, 'B_SHOWINTCP', 1)
                            r.SetMixerScroll(target.object)
                            r.SetOnlyTrackSelected(target.object)
                            r.Main_OnCommand(40913, 0)
                        end,
                        setSolo = function(self, solo, exclusive)
                            self.db:beginUndoBlock()
                            -- deafult to true if solo == SOLO_STATES.SOLO
                            local exclusive = (exclusive ~= false) and (solo == SOLO_STATES.SOLO) or false
                            self:_saveOrigMuteState()
                            -- local sm, counter = self:_getSoloMatrix()
                            -- turn off all solos if exclusive == true
                            -- local j = 0
                            for i, send in ipairs(self.db.sends) do
                                if exclusive and (send ~= self) then
                                    -- local sm, j = send:_getSoloMatrix()
                                    if send.track.soloMatrix[send.guid] == SOLO_STATES.SOLO then
                                        send.track.soloMatrix[send.guid] = SOLO_STATES.NONE
                                    end
                                end
                            end
                            self.track.soloMatrix[self.guid] = solo

                            self.db:_reflectSolos(true)
                            self.db:save()
                            self.db:endUndoBlock('Solo send', 1)
                        end,
                        isListening = function(self)
                            return self.track.sendListen == self.guid
                        end,
                        toggleListen = function(self, listenMode)
                            self.db:beginUndoBlock()
                            local sourceTrack = self.srcTrack or self.track
                            if self.track.sendListen ~= self.guid then
                                if listenMode == SEND_LISTEN_MODES.RETURN_ONLY then
                                    if not sourceTrack.masterSendState then
                                        sourceTrack.masterSendState = r.GetMediaTrackInfo_Value(sourceTrack.object,
                                            'B_MAINSEND') == 1
                                    end
                                    if sourceTrack.masterSendState then
                                        r.SetMediaTrackInfo_Value(sourceTrack.object, 'B_MAINSEND', 0)
                                    end
                                end
                                -- Solo this track and the destTrack
                                r.SetMediaTrackInfo_Value(sourceTrack.object, 'I_SOLO', 2)

                                if self.type ~= SEND_TYPE.HW then r.SetMediaTrackInfo_Value(self.destTrack.object, 'I_SOLO', 2) end
                                -- Un-solo any other track if it's soloed
                                for i, track in ipairs(self.db.tracks) do
                                    if (track.guid ~= self.track.guid) and ((self.type == SEND_TYPE.HW) or (track.guid ~= self.destTrack.guid)) then
                                        local soloState = r.GetMediaTrackInfo_Value(track.object, 'I_SOLO')
                                        if soloState ~= 0 then
                                            r.SetMediaTrackInfo_Value(track.object, 'I_SOLO', 0)
                                        end
                                    end
                                end
                                self:setSolo(SOLO_STATES.SOLO, true)

                                self.track.sendListen = self.guid
                                self.track.sendListenMode = listenMode
                            else
                                if self.db:isListenOn() then
                                    if sourceTrack.masterSendState then
                                        r.SetMediaTrackInfo_Value(sourceTrack.object, 'B_MAINSEND', 1)
                                        sourceTrack.masterSendState = nil
                                    end
                                end
                                self.track.sendListen = nil
                                self.track.sendListenMode = nil
                                -- Un-solo this track and the destTrack
                                r.SetMediaTrackInfo_Value(sourceTrack.object, 'I_SOLO', 0)
                                if self.type ~= SEND_TYPE.HW then
                                    r.SetMediaTrackInfo_Value(self.destTrack.object, 'I_SOLO', 0)
                                end
                                -- Un-solo
                                self:setSolo(SOLO_STATES.NONE)
                            end
                            self.db:save()
                            self.db:endUndoBlock('Toggle send listen', 1)
                        end,
                        _getChannelAlias = function(self)
                            if self.srcChan == -1 then return '' end
                            local chn1, chn2 = self.destChan + 1 - ((self.destChan >= 1024) and 1024 or 0), (self.destChan < 1024) and (self.destChan + SRC_CHANNELS[self.srcChan].numChannels ) or nil
                            if chn2 and chn2-chn1 > 0 then
                                if (chn2 - chn1) >= 2 then
                                    return OUTPUT_CHANNEL_NAMES[chn1] .. '..' .. OUTPUT_CHANNEL_NAMES[chn2]
                                else
                                    return OUTPUT_CHANNEL_NAMES[chn1] .. '/' .. OUTPUT_CHANNEL_NAMES[chn2]
                                end
                            else
                                return OUTPUT_CHANNEL_NAMES[chn1]
                            end
                            
                        end,
                        _saveOrigMuteState = function(self)
                            local numOfSolos = self.db:_numSolos()
                            if numOfSolos == 0 then
                                for i, send in ipairs(self.db.sends) do
                                    send.track.origMuteMatrix[send.guid] = send.mute
                                end
                            end
                        end,
                        addInsert = function(self, fxName) -- undo point is created by TrackFX_AddByName
                            local fxIndex = r.TrackFX_AddByName(self.destTrack.object, fxName, false, -1)
                            if fxIndex == -1 then
                                self.db.app.logger:logError('Cannot add ' .. fxName .. ' to ' .. self.destTrack.name)
                                return false
                            end
                            self.db:sync(true)
                            self.db.app.focusMainReaperWindow = false
                            return true
                        end,
                        toggleVolEnv = function(self, show)
                            local env = reaper.GetTrackSendInfo_Value(self.track.object, self.type, i, "P_ENV:<VOLENV")
                            OD_ToggleShowEnvelope(env, show)
                            self.db:setUndoPoint('Show/hide send volume envelope', 1)
                        end,
                        togglePanEnv = function(self, show)
                            local env = reaper.GetTrackSendInfo_Value(self.track.object, self.type, i, "P_ENV:<PANENV")
                            OD_ToggleShowEnvelope(env, show)
                            self.db:setUndoPoint('Show/hide send pan envelope', 1)
                        end,
                        toggleMuteEnv = function(self, show)
                            local env = reaper.GetTrackSendInfo_Value(self.track.object, self.type, i, "P_ENV:<MUTEENV")
                            OD_ToggleShowEnvelope(env, show)
                            self.db:setUndoPoint('Show/hide send mute envelope', 1)
                        end,
                    }

                    if send.type == SEND_TYPE.HW then 
                        send.name = send:_getChannelAlias() 
                    end
                    send.calculateShortName = function(self) 
                        self.shortName = self.app.minimizeText(send.name, self.app.settings.current.sendWidth-r.ImGui_GetStyleVar(self.app.gui.ctx, r.ImGui_StyleVar_FramePadding()) * 2)
                    end
                    send.app = self.app
                    send:calculateShortName()

                    if send.destTrack then
                        send.destInsertsCount = r.TrackFX_GetCount(send.destTrack.object)
                        send.destInserts, send.destInsertsCount = self:getInserts(send.destTrack.object)
                        if send.destInsertsCount > self.maxNumInserts then
                            self.maxNumInserts = send.destInsertsCount
                        end
                    end

                    local targetId = (type == SEND_TYPE.SEND) and send.destTrack.guid or
                        (type == SEND_TYPE.RECV) and send.srcTrack.guid or send.destChan

                    existingTargetGuidCount[targetId] = (existingTargetGuidCount[targetId]) and
                        (existingTargetGuidCount[targetId] + 1) or 0
                    send.guid = targetId .. '_' .. existingTargetGuidCount[targetId]
                    table.insert(self.guids, send.guid)

                    table.insert(self.sends, send)
                    overallOrder = overallOrder + 1
                end
                if oldNumSends ~= self.numSends[type] then
                    self.app.refreshWindowSizeOnNextFrame = true
                end
            end

            -- since there's no way of having persisted data attached to a specific send,
            -- in case a send was removed, I don't know which exact send it was, so
            -- all sends to the same target's solomatrix and liste states need to be reset,
            local guidsToReset = {}
            local counter = {}
            for _, guid in ipairs(self.lastGuids) do
                if not OD_HasValue(self.guids, guid) then
                    local baseGuid = guid:match('(.*)_%d-$')
                    for _, send in ipairs(self.sends) do
                        local baseSendGuid = send.guid:match('(.*)_%d-$')
                        if baseSendGuid == baseGuid then
                            counter[baseGuid] = counter[baseGuid] and counter[baseGuid] + 1 or 0
                            if counter[baseGuid] > 0 then
                                if not OD_HasValue(guidsToReset, baseGuid) then table.insert(guidsToReset, baseGuid) end
                            end
                        end
                    end
                end
            end
            self.lastGuids = {}
            for _, send in ipairs(self.sends) do
                table.insert(self.lastGuids, send.guid)
            end
            for _, baseGuid in ipairs(guidsToReset) do
                for _, send in ipairs(self.sends) do
                    local baseSendGuid = send.guid:match('(.*)_%d-$')
                    if baseSendGuid == baseGuid then
                        self.surpressUndo = true
                        send:setSolo(SOLO_STATES.NONE)
                        if send:isListening() then
                            send:toggleListen(self.listenMode)
                        end
                        self.surpressUndo = false
                    end
                end
            end
            self.app.setPage(APP_PAGE.MIXER)
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
    if assetType == ASSETS.TRACK then
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
    elseif assetType == ASSETS.PLUGIN then
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
DB.getSelectedTrack = function(self)
    if self.app.settings.current.followSelectedTrack == false and self.track ~= -1 and self.track ~= nil and self.track.object ~= nil and r.ValidatePtr(self.track.object, 'MediaTrack*') then
        return self.track, false
    end
    local track = reaper.GetLastTouchedTrack()
    if (track == nil and self.track ~= nil) or track == self.masterTrack then
        self.trackName = nil
        self.sends = {}
        return (self.track ~= -1 and not self.track.object) and self.track or { }, true
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
        local numChannels = reaper.GetMediaTrackInfo_Value(track, 'I_NCHAN') 
        local volume = reaper.GetMediaTrackInfo_Value(track, 'D_VOL')
        local pan = reaper.GetMediaTrackInfo_Value(track, 'D_PAN')
        local _, rawSsoloMatrix = r.GetSetMediaTrackInfo_String(track, "P_EXT:" .. Scr.ext_name ..
            '_SOLO_MATRIX', "", false)
        local _, rawOrigMuteMatrix = r.GetSetMediaTrackInfo_String(track, "P_EXT:" .. Scr.ext_name ..
            '_ORIG_MUTE_MATRIX', "", false)
        local _, rawMasterSendState = r.GetSetMediaTrackInfo_String(track, "P_EXT:" .. Scr.ext_name ..
            '_MASTER_SEND_STATE', "", false)
        local _, rawSendListen = r.GetSetMediaTrackInfo_String(track, "P_EXT:" .. Scr.ext_name ..
            '_SEND_LISTEN', "", false)
        local soloMatrix = rawSsoloMatrix and unpickle(rawSsoloMatrix) or {}
        local origMuteMatrix = rawOrigMuteMatrix and unpickle(rawOrigMuteMatrix) or {}
        local masterSendState = (rawMasterSendState == '1')
        local sendListen = rawSendListen ~= '' and rawSendListen:match('(.-)%s') or nil
        local sendListenMode = rawSendListen ~= '' and tonumber(rawSendListen:match('.-%s(%d)')) or nil
        table.insert(self.tracks, {
            object = track,
            db = self,
            name = trackName,
            guid = trackGuid,
            color = trackColor,
            vol = volume,
            pan = pan,
            numChannels = numChannels,
            hasReceives = hasReceives,
            soloMatrix = soloMatrix,
            origMuteMatrix = origMuteMatrix,
            masterSendState = masterSendState,
            sendListen = sendListen,
            sendListenMode = sendListenMode,
            order = i,
            setVolDB = function(self, dB) -- because of the complexity of the input mechanism, undo states are handled in the GUI
                if dB < self.db.app.settings.current.minSendVol then
                    dB = self.db.app.settings.current.minSendVol
                elseif dB > self.db.app.settings.current.maxSendVol then
                    dB = self.db.app.settings.current.maxSendVol
                end
                self.vol = (dB <= self.db.app.settings.current.minSendVol and 0 or OD_ValFromdB(dB))
                reaper.SetMediaTrackInfo_Value(self.object, 'D_VOL',self.vol)
                -- self.db:sync(true)
            end,
            setPan = function(self, pan) -- because of the complexity of the input mechanism, undo states are handled in the GUI
                if pan < -1 then
                    pan = -1
                elseif pan > 1 then
                    pan = 1
                end
                self.pan = pan
                reaper.SetMediaTrackInfo_Value(self.object, 'D_PAN', self.pan)
            end,
        })
        -- end
    end
end

DB._getTrack = function(self, track)
    for i, trk in ipairs(self.tracks) do
        if track == trk.object then
            return trk
        end
    end
end

--- SOLOS

DB._numSolos = function(self)
    local numOfSolos = 0
    for i, send in ipairs(self.sends) do
        if send.track.soloMatrix[send.guid] == SOLO_STATES.SOLO then
            numOfSolos = numOfSolos + 1
        end
    end
    return numOfSolos
end
DB._reflectSolos = function(self, resetIfNeeded)
    self.surpressUndo = true
    local numSolos = self:_numSolos()
    if numSolos > 0 then
        for j, send in ipairs(self.sends) do
            send:setMute(send:getSolo() == SOLO_STATES.NONE)
        end
    end
    if resetIfNeeded and numSolos == 0 then
        for j, send in ipairs(self.sends) do
            send:setMute(send.track.origMuteMatrix[send.guid] or false)
        end
    end
    self.surpressUndo = false
end

DB.isListenOn = function(self)
    for i, send in ipairs(self.sends) do
        if send.track.sendListen then
            return true
        end
    end
    return false
end

--- INSERTS
DB.getInserts = function(self, track)
    local fxCount = r.TrackFX_GetCount(track)
    local inserts = {}
    for i = 0, fxCount - 1 do
        local _, fxName = r.TrackFX_GetFXName(track, i, '')
        local offline = r.TrackFX_GetOffline(track, i)
        local enabled = r.TrackFX_GetEnabled(track, i)
        -- local shortName, shortened = self.app.minimizeText(fxName:gsub('.-%:', ''):gsub('%(.-%)$', ''),
        --     self.app.settings.current.sendWidth -
        --     r.ImGui_GetStyleVar(self.app.gui.ctx, r.ImGui_StyleVar_FramePadding()) * 2)
        local insert = 
             {
            order = i,
            db = self,
            name = fxName,
            shortName = fxName,
            shortened = false,
            calculateShortName = function(self)
                self.shortName, self.shortened = self.db.app.minimizeText(self.name:gsub('.-%:', ''):gsub('%(.-%)$', ''),
                    self.db.app.settings.current.sendWidth -
                    r.ImGui_GetStyleVar(self.db.app.gui.ctx, r.ImGui_StyleVar_FramePadding()) * 2)
            end,
            offline = offline,
            enabled = enabled,
            track = track,
            setEnabled = function(self, enabled) -- undo point created by TrackFX_SetEnabled
                r.TrackFX_SetEnabled(self.track, i, enabled)
                self.db:sync(true)
            end,
            setOffline = function(self, offline) -- undo point created by TrackFX_SetOffline
                r.TrackFX_SetOffline(self.track, i, offline)
                self.db:sync(true)
            end,
            delete = function(self) -- undo point created by TrackFX_Delete
                r.TrackFX_Delete(self.track, i)
                self.db:sync(true)
            end,
            toggleShow = function(self) -- showing FX does not create undo points
                if not r.TrackFX_GetOpen(self.track, i) then
                    r.TrackFX_Show(self.track, i, 3)
                    return true
                else
                    r.TrackFX_Show(self.track, i, 2)
                    return false
                end
            end
        }
        insert:calculateShortName()
        table.insert(inserts, insert)
    end
    return inserts, fxCount
end
DB.recalculateShortNames = function(self)
    for _, send in ipairs(self.sends) do
        for _, insert in ipairs(send.destInserts) do
            insert:calculateShortName()
        end
        send:calculateShortName()
    end
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
            plugin.group = plugin.fx_type
        end
        i = i + 1
        if not found then break end
    end
end

DB.markFavorites = function(self)
    for _, asset in ipairs(self.assets) do
        if OD_HasValue(self.app.settings.current.favorites, asset.type .. ' ' .. asset.load) then 
            asset.originalGroup = asset.group
            asset.group = FAVORITE_GROUP
        end
    end
end

-- ASSETS

DB.assembleAssets = function(self)
    self.assets = {}

    local toggleFavorite = function(self)
        local favorite = self.db.app.settings.current.favorites
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
        self.db.app.settings:save()
        self.db:sortAssets()
        return self.group == FAVORITE_GROUP
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
    end
    for _, plugin in ipairs(self.plugins) do
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
    end

    self:markFavorites()
    self:sortAssets()
end

DB.sortAssets = function(self)
    local groupPriority = {}
    for i, group in ipairs(self.app.settings.current.fxTypeOrder) do
        groupPriority[group] = i
    end
    groupPriority[FAVORITE_GROUP] = -2
    groupPriority[RECEIVES_GROUP] = -1
    groupPriority[TRACKS_GROUP] = 0

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
