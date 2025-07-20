-- @noindex
-- Track Template Asset Type Module

TrackTemplateAssetType = {}
TrackTemplateAssetType.__index = TrackTemplateAssetType
setmetatable(TrackTemplateAssetType, BaseAssetType)

function TrackTemplateAssetType.new(class, context)
    local instance = BaseAssetType.new(class, {
        name = "Track Template",
        assetTypeId = ASSETS.TRACK_TEMPLATE,
        group = "Track Templates", -- Use display name as group
        context = context
    })
    instance.trackTemplates = {} -- Store track templates locally in the module
    return instance
end

function TrackTemplateAssetType:getData()
    self.context.logger:logDebug('-- TrackTemplateAssetType:getData()')
    self.trackTemplates = {} -- Clear local track templates array
    local basePath = reaper.GetResourcePath() .. "/TrackTemplates"
    local files = OD_GetFilesInFolderAndSubfolders(basePath, 'RTrackTemplate', true)
    local count = 0
    for i, file in ipairs(files) do
        local path, baseFilename, ext = OD_DissectFilename(file)
        local ttLoad, ttPath = basePath .. OD_FolderSep() .. file, path:gsub('\\', '/'):gsub('/$', '')
        self.context.logger:logDebug('Found track template', ttLoad)
        table.insert(self.trackTemplates, {
            load = ttLoad,
            path = ttPath,
            file = baseFilename,
            ext = ext
        })
        count = count + 1
    end
    self.context.logger:logInfo('Found ' .. count .. ' track templates')
    return self.trackTemplates
end

function TrackTemplateAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- Track templates can be loaded as new tracks or applied to existing tracks
        -- Implementation would depend on the specific context and requirements
    end
end

function TrackTemplateAssetType:assembleAsset(tt)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = tt.load,
        searchText = { { text = tt.file }, { text = tt.path }, { text = tt.ext, hide = true } },
        group = self.group,
        order = 0
    })
    
    return asset
end
