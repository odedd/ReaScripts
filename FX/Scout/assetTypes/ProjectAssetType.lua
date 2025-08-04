-- @noindex
-- Project Asset Type Module

ProjectAssetType = {}
ProjectAssetType.__index = ProjectAssetType
setmetatable(ProjectAssetType, BaseAssetType)

function ProjectAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Project", "Projects")(class, context)
    instance.allowMultiple = false
    instance:addInteraction(0, 'open %asset',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            r.Main_openProject(asset.load)
            return true
        end)
    -- -- This is dependent on a setting which apparently is not exposed to get_config_var_string - "Create new project tab when opening media from explorer/finder",
    -- -- so I can't guarantee it always works. Better to comment it out until an API exists.
    instance:addInteraction(ImGui.Mod_Shift, 'open %asset in a new tab',
        function(asset, mods, context, contextData, confirm, total, index, tempStore)
            reaper.Main_OnCommand(40859, 0)
            r.Main_openProject(asset.load)
            return true
        end)

    return instance
end

function ProjectAssetType:getData()
    local data = {} -- Use consistent local variable naming

    -- Local function to get recent projects from reaper.ini
    local function getRecentProjects()
        local recentProjects = {}
        local iniPath = reaper.get_ini_file():gsub("\\", "/")
        local content = OD_GetContent(iniPath)

        if content and content ~= "" then
            -- Find the [Recent] section
            local recentSection = content:match("%[Recent%](.-)\n%[")
            if not recentSection then
                recentSection = content:match("%[Recent%](.*)")
            end

            if recentSection then
                -- Parse recent entries (recent01=path, recent02=path, etc.)
                for line in recentSection:gmatch("[^\n]+") do
                    local recentPath = line:match("recent%d+=(.+)")
                    if recentPath and recentPath ~= "" then
                        -- Check if file exists and is a .RPP file
                        if recentPath:lower():match("%.rpp$") and OD_FileExists(recentPath) then
                            local path, name, ext = OD_DissectFilename(recentPath)
                            table.insert(recentProjects, {
                                fullPath = recentPath,
                                name = name,
                                path = path,
                                recent = true,
                            })
                        end
                    end
                end
            end
        end

        return recentProjects
    end

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
                    path = folderPath .. '/' .. path,
                })
            end
        else
            self.context.logger:logError('Project scan folder does not exist or is not accessible: ' .. folderPath)
        end
    end

    -- Add recent projects from reaper.ini
    local recentProjects = getRecentProjects()
    self.context.logger:logDebug('Found ' .. #recentProjects .. ' recent projects from reaper.ini')
    for _, project in ipairs(recentProjects) do
        table.insert(data, project)
    end

    return data
end

function ProjectAssetType:assembleAsset(project)
    if not self.context.settings.current.scanRecentProjects and project.recent then return nil end
    
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = project.fullPath,
        searchText = {
            { text = project.name },
            { text = project.path }
        },
        group = self.group,
    })

    if project.recent then
        table.insert(asset.searchText, { text = '(Recently opened)' })
    end
    return asset
end
