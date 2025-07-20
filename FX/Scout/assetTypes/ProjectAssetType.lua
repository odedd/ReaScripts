-- @noindex
-- Project Asset Type Module

ProjectAssetType = {}
ProjectAssetType.__index = ProjectAssetType
setmetatable(ProjectAssetType, BaseAssetType)

ProjectAssetType.new = BaseAssetType:createStandardConstructor("Projects", ASSETS.PROJECT, PROJECTS_GROUP)

function ProjectAssetType:getData()
    self.context.logger:logDebug('-- ProjectAssetType:getData()')
    self.data = {}
    
    -- Get project scan folders from settings
    local scanFolders = self.context.settings.current.projectScanFolders or {}
    
    for _, folderPath in ipairs(scanFolders) do
        if OD_FolderExists(folderPath) then
            self.context.logger:logDebug('Scanning folder for RPP files: ' .. folderPath)
            local projectFiles = OD_GetFilesInFolderAndSubfolders(folderPath, "rpp", true)
            
            for _, relativePath in ipairs(projectFiles) do
                local fullPath = folderPath .. OD_FolderSep() .. relativePath
                local path, name, ext = OD_DissectFilename(relativePath)
                
                table.insert(self.data, {
                    fullPath = fullPath,
                    name = name,
                    path = folderPath..'/'..path,
                    order = #self.data
                })
            end
        else
            self.context.logger:logWarning('Project scan folder does not exist: ' .. folderPath)
        end
    end
    
    self:logDataStats("projects", #self.data)
    return self.data
end

function ProjectAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- Open the project file in Reaper
        r.Main_openProject("noprompt:" .. self.load)
    end
end

function ProjectAssetType:assembleAsset(project)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = project.fullPath,
        searchText = { 
            { text = project.name }, 
            { text = project.path }
        },
        group = self.group,
        order = project.order
    })
    
    return asset
end
