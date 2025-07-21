-- @noindex
-- Track Asset Type Module

TrackAssetType = {}
TrackAssetType.__index = TrackAssetType
setmetatable(TrackAssetType, BaseAssetType)

function TrackAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Track", "Tracks")(class, context)
    -- Tracks should be imported even if they can't be mapped to existing tracks
    instance.requiresMappingOnImport = false
    return instance
end

function TrackAssetType:getData()
    local data = {} -- Use consistent local variable naming
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
        table.insert(data, trackData)
    end
    return data
end

function TrackAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- Track execution - currently no default action implemented
        -- Could implement track selection: r.SetOnlyTrackSelected(self.load)
        -- For now, return true since there's no actual action to fail
        return true
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
