-- @noindex

DB = {
    stems = {},
    error = nil,
    renderPresets = {},
    getRenderPresets = function(self)
        self.renderPresets = {}
        local path = string.format('%s/reaper-render.ini', r.GetResourcePath())
        if not r.file_exists(path) then
            return {}
        end

        local file, err = assert(io.open(path, 'r'))

        local tokens = {}
        self.renderPresets = {}
        for line in file:lines() do
            tokens = tokenize(line)
            if (tokens[1] == '<RENDERPRESET' or tokens[1] == 'RENDERPRESET_OUTPUT') and not (tokens[2] == "") and
                tokens[2] then
                local name = tokens[2]
                local folder = tokens[10]
                self.renderPresets[name] = self.renderPresets[name] or {}
                self.renderPresets[name].name = name
                self.renderPresets[name].folder = folder or ""
                self.renderPresets[name].filepattern = tokens[8] or self.renderPresets[name].filepattern
                if tokens[6] then
                    self.renderPresets[name].settings = (tonumber(tokens[6]) & SETTINGS_SOURCE_MASK) |
                        (self.renderPresets[name].settings or 0)
                end
                if tokens[3] then
                    self.renderPresets[name].boundsflag = tonumber(tokens[3])
                end
            end
        end
        file:close()
    end,
    savePreset = function(self, fileName)
        local preset = {
            version = Scr.version,
            stems = OD_DeepCopy(self.stems),
            settings = Settings.project
        }
        for k, stem in pairs(preset.stems) do
            stem.sync = SYNCMODE_OFF
        end
        table.save(preset, fileName)
    end,
    loadPreset = function(self, fileName, fullLoad)
        local preset = table.load(fileName)
        if preset == nil then
            reaper.ShowConsoleMsg('Preset loading error\n')
        elseif OD_GetMinorVersion(preset.version) > Scr.minor_version then
            reaper.ShowConsoleMsg(('The preset was saved using a newer version of %s\n'):format(Scr.name))
        else
            Settings.project = OD_DeepCopy(preset.settings)
            SaveSettings()
            if fullLoad then
                for stemName, stem in pairs(self.stems) do
                    self:removeStem(stemName)
                end
                self.stems = OD_DeepCopy(preset.stems)
                self:sync()
            end
        end
    end,
    resetStem = function(self, stemName)
        for i, track in ipairs(self.tracks) do
            self:setTrackStateInStem(track, stemName)
        end
    end,
    reflectTrackOnStem = function(self, stemName, track, persist)
        if persist == nil then
            persist = false
        end
        local found = false
        for state, v in pairs(STATE_RPR_CODES) do
            if v['I_SOLO'] == r.GetMediaTrackInfo_Value(track.object, 'I_SOLO') and v['B_MUTE'] ==
                r.GetMediaTrackInfo_Value(track.object, 'B_MUTE') then
                self:setTrackStateInStem(track, stemName, state, false, false)
                found = true
                break
            end
            if not found then
            else
                self:setTrackStateInStem(track, stemName, nil, false, false)
            end
        end
        if persist then
            self:save()
        end
    end,
    reflectAllTracksOnStem = function(self, stemName)
        for i, track in ipairs(self.tracks) do
            self:reflectTrackOnStem(stemName, track)
        end
        self:save()
    end,
    reflectStemOnTrack = function(self, stemName, track)
        if not (r.GetMediaTrackInfo_Value(track.object, 'I_SOLO') ==
                STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['I_SOLO']) then
            r.SetMediaTrackInfo_Value(track.object, 'I_SOLO',
                STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['I_SOLO'])
        end
        if not (r.GetMediaTrackInfo_Value(track.object, 'B_MUTE') ==
                STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['B_MUTE']) then
            r.SetMediaTrackInfo_Value(track.object, 'B_MUTE',
                STATE_RPR_CODES[track.stemMatrix[stemName] or ' ']['B_MUTE'])
        end
    end,
    reflectStemOnAllTracks = function(self, stemName)
        -- first only solo/mute tracks
        for i, track in ipairs(self.tracks) do
            if track.stemMatrix[stemName] ~= ' ' and track.stemMatrix[stemName] ~= nil then
                self:reflectStemOnTrack(stemName, track)
            end
        end
        -- and only then unmute previous tracks
        for i, track in ipairs(self.tracks) do
            if track.stemMatrix[stemName] == ' ' or track.stemMatrix[stemName] == nil then
                self:reflectStemOnTrack(stemName, track)
            end
        end
    end,
    saveSoloState = -- save current projects solo state to a temporary variable,
    -- for use after stem syncing is turned off
        function(self)
            self.savedSoloStates = {}
            for i = 0, r.CountTracks(0) - 1 do
                local track = r.GetTrack(0, i)
                self.savedSoloStates[r.GetTrackGUID(track)] = {
                    ['solo'] = r.GetMediaTrackInfo_Value(track, 'I_SOLO'),
                    ['mute'] = r.GetMediaTrackInfo_Value(track, 'B_MUTE')
                }
            end
            self:save()
        end,
    recallSoloState = function(self)
        for i = 0, r.CountTracks(0) - 1 do
            local track = r.GetTrack(0, i)
            local trackGUID = r.GetTrackGUID(track)
            local savedState = self.savedSoloStates[trackGUID]
            if savedState then
                if not (r.GetMediaTrackInfo_Value(track, 'I_SOLO') == savedState.solo) then
                    r.SetMediaTrackInfo_Value(track, 'I_SOLO', savedState.solo)
                end
                if not (r.GetMediaTrackInfo_Value(track, 'B_MUTE') == savedState.mute) then
                    r.SetMediaTrackInfo_Value(track, 'B_MUTE', savedState.mute)
                end
            end
        end
    end,
    toggleStemSync = function(self, stem, toggleTo)
        -- if toggleTo is left blank, toggles according to current state
        -- find if the request came when another stem is soloed,
        -- otherwise, save project solo states (at a later point)
        -- if it did and it's turned off than recall solo states
        local syncingStemFound = false
        for k, st in pairs(self.stems) do
            syncingStemFound = syncingStemFound or (st.sync ~= SYNCMODE_OFF and st.sync ~= nil)
        end
        for k, st in pairs(self.stems) do
            if stem == st then
                if toggleTo ~= SYNCMODE_OFF then
                    if not syncingStemFound then
                        self:saveSoloState()
                    end
                    self:reflectStemOnAllTracks(k)
                elseif syncingStemFound then
                    self:recallSoloState()
                end
                st.sync = toggleTo
            else
                -- set all other stems to not sync
                st.sync = SYNCMODE_OFF
            end
        end
        self:save()
    end,
    setTrackStateInStem = function(self, track, stemName, state, persist, reflect)
        if persist == nil then
            persist = true
        end
        if reflect == nil then
            reflect = (self.stems[stemName].sync ~= SYNCMODE_OFF)
        end
        if state == ' ' then
            state = nil
        end
        track.stemMatrix[stemName] = state
        if reflect then
            self:reflectStemOnTrack(stemName, track)
        end
        if persist then
            self:save()
        end
    end,
    findSimilarStem = function(self, name, findSame)
        if findSame == nil then
            findSame = false
        end
        for k, v in pairs(self.stems) do
            if (k:upper() == name:upper()) and (findSame or (not (k == name))) then
                return k
            end
        end
    end,
    addStem = function(self, name, copy)
        local persist = false
        -- if a stem exist with the same name but different case (e.g., drums / Drums)
        -- rename the added stem to the new one and dont create it
        local existingSimilarName = self:findSimilarStem(name)
        if not (existingSimilarName == nil) then
            -- look for all track with reference to the found stem and change their case
            for i, track in ipairs(self.tracks) do
                for k, v in pairs(track.stemMatrix) do
                    if k == name then
                        track.stemMatrix[existingSimilarName] = v
                        track.stemMatrix[k] = nil
                    end
                end
            end
        elseif not self.stems[name] then
            persist = true
            self.stemCount = (self.stemCount or 0) + 1
            self.stems[name] = {
                order = self.stemCount,
                sync = SYNCMODE_OFF,
                render_setting_group = 1
            }
            -- get render setting group from last stem in list
            for k, v in OD_PairsByOrder(self.stems) do
                if v.order == self.stemCount - 1 then
                    self.stems[name].render_setting_group = v.render_setting_group
                end
            end
            if copy then
                self:reflectAllTracksOnStem(name)
            end
        end
        if persist then
            self:save()
        end
    end,
    removeStem = function(self, stemName)
        -- turn off sync if this stem is syncing
        if (self.stems[stemName].sync ~= SYNCMODE_OFF) and (self.stems[stemName].sync ~= nil) then
            self:toggleStemSync(self.stems[stemName], SYNCMODE_OFF)
        end
        -- remove any states related to the stem from tracks
        for i, track in ipairs(self.tracks) do
            self:setTrackStateInStem(track, stemName, nil, false)
        end
        -- reorder remaining stems
        for k, v in pairs(self.stems) do
            if v.order > self.stems[stemName].order then
                self.stems[k].order = self.stems[k].order - 1
            end
        end
        -- remove stem
        self.stems[stemName] = nil
        self:save()
    end,
    reorderStem = function(self, stemName, newPos)
        local oldPos = self.stems[stemName].order
        for k, v in pairs(self.stems) do
            if (v.order >= newPos) and (v.order < oldPos) then
                self.stems[k].order = self.stems[k].order + 1
            end
            if (v.order <= newPos) and (v.order > oldPos) then
                self.stems[k].order = self.stems[k].order - 1
            end
        end
        self.stems[stemName].order = newPos
        self:save()
    end,
    renameStem = function(self, stemName, newName)
        if not (newName == stemName) then
            for i, track in ipairs(self.tracks) do
                for k, v in pairs(track.stemMatrix) do
                    if k == stemName then
                        track.stemMatrix[newName] = v
                        track.stemMatrix[k] = nil
                    end
                end
            end
            self.stems[newName] = self.stems[stemName]
            self.stems[stemName] = nil
            self:save()
        end
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
            if foundTrackInfo.stemMatrix and not (foundTrackInfo.stemMatrix == '') then
                local retval = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_STEM_MATRIX',
                    pickle(foundTrackInfo.stemMatrix), true)
            else
                r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name .. '_STEM_MATRIX', '', true)
            end
        end
        OD_SaveLongProjExtState(Scr.ext_name, 'STEMS', pickle(self.stems or {}))
        for k, v in pairs(self.savedSoloStates) do
            r.SetProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', k, pickle(v))
        end
        r.MarkProjectDirty(0)
    end,
    sync = function(self, full)
        if App.debug then
            tim = os.clock()
        end
        self.cycles = self.cycles or 0
        if self.cycles == 0 then
            full = true
        end                                                    -- if first cycle, force full sync
        self.current_project = r.GetProjectStateChangeCount(0) -- if project changed, force full sync
        if self.current_project ~= self.previous_project then
            self.previous_project = self.current_project
            full = true
        end

        if full then
            if App.debug then
                r.ShowConsoleMsg('FULL SYNC\n')
            end
            self.stems = unpickle(OD_LoadLongProjExtKey(Scr.ext_name, 'STEMS')) or {}
            self.prefSoloIP = select(2, r.get_config_var_string('soloip')) == '1'
        end

        self.trackChangeTracking = self.trackChangeTracking or ''
        self.tracks = self.tracks or {}
        self.stemToSync = nil
        self.error = nil
        self.stemCount = 0;

        -- load savedSoloStates
        if full then
            self.savedSoloStates = {}
            i = 0
            local retval, k, v = r.EnumProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', i)
            while retval do
                self.savedSoloStates[k] = unpickle(v)
                i = i + 1
                retval, k, v = r.EnumProjExtState(0, Scr.ext_name .. '_SAVED_SOLO_STATES', i)
            end
            self.savedSoloStates = self.savedSoloStates or {}
        end
        -- iterate stems, count them and mark them as the stem to sync if necessary
        for k, stem in pairs(self.stems or {}) do
            self.stemCount = self.stemCount + 1
            if stem.sync ~= SYNCMODE_OFF and stem.sync ~= nil then
                self.stemToSync = k
                self.syncMode = stem.sync
            end
        end
        local trackCount = r.CountTracks(0)
        self.lastTrackCount = self.lastTrackCount or trackCount

        if full or self.lastTrackCount ~= trackCount then
            self.lastTrackCount = trackCount
            self.tracks = {}
            for trackIdx = 0, trackCount - 1 do
                local rTrack = r.GetTrack(0, trackIdx)
                local _, name = r.GetSetMediaTrackInfo_String(rTrack, "P_NAME", "", false)
                local folderDepth = r.GetMediaTrackInfo_Value(rTrack, "I_FOLDERDEPTH")
                local hidden = (r.GetMediaTrackInfo_Value(rTrack, "B_SHOWINTCP") == 0)
                local color = r.GetTrackColor(rTrack)
                local _, rawStemMatrix = r.GetSetMediaTrackInfo_String(rTrack, "P_EXT:" .. Scr.ext_name ..
                    '_STEM_MATRIX', "", false)
                local stemMatrix = unpickle(rawStemMatrix)
                local trackInfo = {
                    object = rTrack,
                    name = name,
                    folderDepth = folderDepth,
                    color = color,
                    hidden = hidden,
                    stemMatrix = stemMatrix or {}
                }
                -- iterate tracks to create stems
                if trackInfo then
                    table.insert(self.tracks, trackInfo)
                end
                for k, v in pairs(trackInfo.stemMatrix or {}) do
                    self:addStem(k, false)
                end
            end
        end

        for i, track in ipairs(self.tracks) do
            -- if stem is syncing, sync it
            if (self.stemToSync) and (self.syncMode == SYNCMODE_MIRROR) then
                self:reflectTrackOnStem(self.stemToSync, track)
            end
        end
        self.cycles = self.cycles + 1
        if App.debug then
            self.cumlativeTime = self.cumlativeTime and (self.cumlativeTime + (os.clock() - tim)) or
                (os.clock() - tim)
            if self.cycles / 10 == math.ceil(self.cycles / 10) then
                r.ShowConsoleMsg(string.format("average over %d sync operations: %.10f\n", self.cycles,
                    self.cumlativeTime / self.cycles))
            end
        end
    end
}