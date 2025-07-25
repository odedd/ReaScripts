-- @noindex
-- Take Asset Type Module

TakeAssetType = {}
TakeAssetType.__index = TakeAssetType
setmetatable(TakeAssetType, BaseAssetType)

function TakeAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Take", "Takes")(class, context)
    -- Takess should be imported even if they can't be mapped to existing takes
    instance.requiresMappingOnImport = false
    return instance
end

function TakeAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local numTracks = reaper.CountTracks(0)
    
    for trackIdx = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, trackIdx)
        local numItems = reaper.CountTrackMediaItems(track)
        
        for itemIdx = 0, numItems - 1 do
            local item = reaper.GetTrackMediaItem(track, itemIdx)
            local numTakes = reaper.CountTakes(item)
            
            for takeIdx = 0, numTakes - 1 do
                local take = reaper.GetTake(item, takeIdx)
                if take then
                    local takeName = reaper.GetTakeName(take)
                    local takeGuid = reaper.BR_GetMediaItemTakeGUID(take)
                    local isActiveTake = reaper.GetActiveTake(item) == take
                    
                    -- Only include active takes
                    if isActiveTake then
                        self.context.logger:logDebug('Active take added', takeName)
                        
                        -- Capture context from asset type scope
                        local context = self.context
                        
                        local takeData = {
                            object = take,
                            item = item,
                            track = track,
                            engine = context.engine,
                            guid = takeGuid,
                            name = takeName,
                            trackIdx = trackIdx,
                            itemIdx = itemIdx,
                            takeIdx = takeIdx,
                            _refreshName = function(self)
                                self.name = reaper.GetTakeName(self.object)
                            end
                        }
                        takeData:_refreshName()
                        table.insert(data, takeData)
                    end
                end
            end
        end
    end
    return data
end

function TakeAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- Take execution - select only this take's item and set as active take
        
        -- Find the take by GUID
        local targetGuid = self.load
        local numTracks = reaper.CountTracks(0)
        
        -- First, clear all current selections
        reaper.SelectAllMediaItems(0, false)
        
        for trackIdx = 0, numTracks - 1 do
            local track = reaper.GetTrack(0, trackIdx)
            local numItems = reaper.CountTrackMediaItems(track)
            
            for itemIdx = 0, numItems - 1 do
                local item = reaper.GetTrackMediaItem(track, itemIdx)
                local numTakes = reaper.CountTakes(item)
                
                for takeIdx = 0, numTakes - 1 do
                    local take = reaper.GetTake(item, takeIdx)
                    if take then
                        local takeGuid = reaper.BR_GetMediaItemTakeGUID(take)
                        if takeGuid == targetGuid then
                            -- Found the take, select ONLY this item and set this as active take
                            reaper.SetMediaItemSelected(item, true)
                            reaper.SetActiveTake(take)
                            reaper.UpdateArrange()
                            return true
                        end
                    end
                end
            end
        end
        
        return false -- Take not found
    end
end

function TakeAssetType:assembleAsset(takeData)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = takeData.guid,
        searchText = { { text = takeData.name } },
        group = self.group,
    })
    asset.trackIdx = takeData.trackIdx
    asset.itemIdx = takeData.itemIdx
    asset.takeIdx = takeData.takeIdx
    
    return asset
end
