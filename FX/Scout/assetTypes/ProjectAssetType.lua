-- @noindex
-- Project Asset Type Module

ProjectAssetType = {}
ProjectAssetType.__index = ProjectAssetType
setmetatable(ProjectAssetType, BaseAssetType)

ProjectAssetType.new = BaseAssetType:createStandardConstructor("Project", "Projects")

function ProjectAssetType:getData()
    local data = {} -- Use consistent local variable naming
    
    -- Get project scan folders from settings
    local scanFolders = self.context.settings.current.projectScanFolders or {}
    
    for _, folderPath in ipairs(scanFolders) do
        -- Try to scan the folder directly instead of using OD_FolderExists which can be unreliable
        self.context.logger:logDebug('Scanning folder for RPP files: ' .. folderPath)
        local success, projectFiles = pcall(OD_GetFilesInFolderAndSubfolders, folderPath, "rpp", true)
        
        if success and projectFiles then
            for _, relativePath in ipairs(projectFiles) do
                local fullPath = folderPath .. OD_FolderSep() .. relativePath
                local path, name, ext = OD_DissectFilename(relativePath)
                
                table.insert(data, {
                    fullPath = fullPath,
                    name = name,
                    path = folderPath..'/'..path,
                })
            end
        else
            self.context.logger:logError('Project scan folder does not exist or is not accessible: ' .. folderPath)
        end
    end
    
    return data
end

function ProjectAssetType:getExecuteFunction()
    return function(self, mods, context, contextData)
        -- Open the project file in Reaper
        r.Main_openProject(self.load)
        return true
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
    })
    
    return asset
end
