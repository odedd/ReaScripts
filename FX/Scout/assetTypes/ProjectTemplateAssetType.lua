-- @noindex
-- Project Template Asset Type Module

ProjectTemplateAssetType = {}
ProjectTemplateAssetType.__index = ProjectTemplateAssetType
setmetatable(ProjectTemplateAssetType, BaseAssetType)

ProjectTemplateAssetType.new = BaseAssetType:createStandardConstructor("Project Template", "Project Templates")

function ProjectTemplateAssetType:getData()
    local data = {} -- Use consistent local variable naming

    -- Get project scan folders from settings
    local resource_path = reaper.GetResourcePath()
    
    local folderPath = resource_path .. '/ProjectTemplates'
    if OD_FolderExists(folderPath) then
        self.context.logger:logDebug('Scanning template folder for RPP files: ' .. folderPath)
        local projectFiles = OD_GetFilesInFolderAndSubfolders(folderPath, "rpp", true)

        for _, relativePath in ipairs(projectFiles) do
            local fullPath = folderPath .. OD_FolderSep() .. relativePath
            local path, name, ext = OD_DissectFilename(relativePath)

            table.insert(data, {
                fullPath = fullPath,
                name = name,
                path = folderPath .. '/' .. path,
                order = #data
            })
        end
    else
        self.context.logger:logError('Project Template scan folder does not exist: ' .. folderPath)
    end

    return data
end

function ProjectTemplateAssetType:getExecuteFunction()
    return function(self, context, contextData)
        -- Open the project file in Reaper
        r.Main_openProject("template:" .. self.load)
        return true
    end
end

function ProjectTemplateAssetType:assembleAsset(project)
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
