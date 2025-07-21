-- @noindex
-- FX Chain Asset Type Module

FXChainAssetType = {}
FXChainAssetType.__index = FXChainAssetType
setmetatable(FXChainAssetType, BaseAssetType)

FXChainAssetType.new = BaseAssetType:createStandardConstructor("FX Chain", "FX Chains")

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

function FXChainAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- FX Chains are typically loaded into tracks like plugins
        if context == RESULT_CONTEXT.MAIN then
            local tracks = self.context.db:getSelectedTracks()
            -- Conditions are good for execution, add to all tracks regardless of individual success
            for i = 1, #tracks do
                tracks[i]:addInsert(self.load)
            end
            return true
        end
        
        -- Default return for other contexts
        return false
    end
end

function FXChainAssetType:assembleAsset(chain)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = chain.load,
        searchText = { { text = chain.file }, { text = chain.path }, { text = chain.ext, hide = true } },
        group = self.group,
        order = 0
    })
    
    return asset
end
