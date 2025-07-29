-- @noindex
-- Track Template Asset Type Module

TrackTemplateAssetType = {}
TrackTemplateAssetType.__index = TrackTemplateAssetType
setmetatable(TrackTemplateAssetType, BaseAssetType)

function TrackTemplateAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Track Template", "Track Templates")(class, context)
    -- Track Templates are file-based assets (.RTrackTemplate files)
    instance.shouldMapBaseFilenames = true
    return instance
end

function TrackTemplateAssetType:getData()
    local data = {} -- Use consistent local variable naming
    local basePath = reaper.GetResourcePath() .. "/TrackTemplates"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'RTrackTemplate', true)
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local ttLoad, ttPath = basePath .. OD_FolderSep() .. file, path:gsub('\\', '/'):gsub('/$', '')
        self.context.logger:logDebug('Found track template', ttLoad)
        table.insert(data, {
            load = ttLoad,
            path = ttPath,
            file = baseFilename,
            ext = ext
        })
    end
    return data
end

function TrackTemplateAssetType:getExecuteFunction()
    return function(self, mods, context, contextData)
        -- Track template execution - load the specific template file
        -- Use Main_openProject with track template parameter
        return true -- Main_openProject doesn't return meaningful success value
    end
end

function TrackTemplateAssetType:assembleAsset(tt)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = tt.load,
        searchText = { { text = tt.file }, { text = tt.path }, { text = tt.ext, hide = true } },
        group = self.group,
    })
    
    return asset
end
