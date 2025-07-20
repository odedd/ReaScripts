-- @noindex
-- Track Asset Type Module

TrackAssetType = {}
TrackAssetType.__index = TrackAssetType
setmetatable(TrackAssetType, BaseAssetType)

function TrackAssetType.new(class, context)
    local instance = BaseAssetType.new(class, {
        name = "Track",
        assetTypeId = ASSETS.TRACK,
        group = "Tracks", -- Use display name as group
        context = context
    })
    instance.tracks = {} -- Store tracks locally in the module
    return instance
end

function TrackAssetType:getData()
    self.context.logger:logDebug('-- TrackAssetType:getData()')
    -- self:sync()
    self.tracks = {} -- Clear local tracks array
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local trackName = select(2, reaper.GetTrackName(track))
        local trackGuid = reaper.GetTrackGUID(track)
        self.context.logger:logDebug('Track added', trackName)
        
        -- Capture context from asset type scope
        local context = self.context
        
        local trackData = {
            object = track,
            db = context.db,
            guid = trackGuid,
            order = i,
            addInsert = function(self, fxName) -- undo point is created by TrackFX_AddByName
                local fxIndex = r.TrackFX_AddByName(self.object, fxName, false, -1)
                if fxIndex == -1 then
                    context.logger:logError('Cannot add ' .. fxName .. ' to ' .. trackName)
                    return false
                end
                context.db:sync(true)
                return true
            end,
            _refreshColor = function(self)
                local color = ImGui.ColorConvertNative(reaper.GetTrackColor(track)) * 0x100 | 0xff
                self.color = color
            end,
            _refreshName = function(self)
                self.name = select(2, reaper.GetTrackName(self.object))
            end
        }
        trackData:_refreshName()
        trackData:_refreshColor()
        table.insert(self.tracks, trackData)
    end
    self.context.logger:logDebug('Found ' .. numTracks .. ' tracks')
    return self.tracks
end

function TrackAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- Track execution might involve selection or other track operations
        -- Currently commented out in original: r.SetOnlyTrackSelected(self.load)
    end
end

function TrackAssetType:assembleAsset(track)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = track.guid,
        searchText = { { text = track.name } },
        group = self.group,
        order = track.order
    })
    asset.color = track.color
    
    return asset
end
