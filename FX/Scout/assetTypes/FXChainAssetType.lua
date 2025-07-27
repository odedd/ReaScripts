-- @noindex
-- FX Chain Asset Type Module

FXChainAssetType = {}
FXChainAssetType.__index = FXChainAssetType
setmetatable(FXChainAssetType, BaseAssetType)

function FXChainAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("FX Chain", "FX Chains")(class, context)
    -- FX Chains are file-based assets (.rfxchain files)
    instance.shouldMapBaseFilenames = true

    instance:addInteraction(0, 'load FX Chain %asset to selected track(s)', function(asset, context, contextData, confirm)
        local selectedTracks = instance:getSelectedTracksWithConfirmation(context, contextData, confirm)

        if selectedTracks and #selectedTracks > 0 then
            local originalUIState = instance:setPluginUIState()
            for _, track in ipairs(selectedTracks) do
                local fxIndex = r.TrackFX_AddByName(track, asset.load, false, -1)
            end
            instance:resetPluginUIState(originalUIState)
            return true, ('Added %s to %d tracks'):format(asset.searchText[1].text, #selectedTracks)
        elseif selectedTracks and #selectedTracks == 0 then
            return false, 'No tracks selected'
        end
    end)

    return instance
end

function FXChainAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local basePath = reaper.GetResourcePath() .. "/FXChains/"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'rfxchain', true)
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local chainPath = path:gsub('\\', '/'):gsub('/$', '')
        self.context.logger:logDebug('Found FX chain', file)
        table.insert(data, {
            load = file,
            path = chainPath,
            file = baseFilename,
            ext = ext
        })
    end
    return data
end

function FXChainAssetType:assembleAsset(chain)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = chain.load,
        searchText = { { text = chain.file }, { text = chain.path }, { text = chain.ext, hide = true } },
        group = self.group,
    })

    return asset
end
