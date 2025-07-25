-- @noindex
-- Action Asset Type Module

ActionAssetType = {}
ActionAssetType.__index = ActionAssetType
setmetatable(ActionAssetType, BaseAssetType)

function ActionAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("Action", "Actions")(class, context)
    -- Plugins are file-based assets (have file paths)
    instance.shouldMapBaseFilenames = true
    instance.interactionModifiers[0] = 'run %asset'
    return instance
end

function ActionAssetType:getData()
    local data = {} -- Use consistent local variable naming
    
    local idx = 0
    local section = 0 --implement different section if needed
    while true do
        local cmdId, name = reaper.kbd_enumerateActions(section, idx)
        if cmdId == 0 then break end
        local prefix, actionName = name:match("^(.-):%s*(.*)$")
        if not prefix then
            prefix = ""
            actionName = name
        end
        name = actionName
        -- Get keyboard shortcuts for this action
        local shortcuts = {}
        local shortcutCount = reaper.CountActionShortcuts(section, cmdId)
        for sc = 0, shortcutCount - 1 do
            local rv, desc = reaper.GetActionShortcutDesc(section, cmdId, sc)
            if desc and desc ~= "" then
                table.insert(shortcuts, desc)
            end
        end

        table.insert(data, {
            numericId = cmdId,
            namedId = reaper.ReverseNamedCommandLookup(cmdId),
            name = name,
            prefix = prefix,
            section = section,
            shortcuts = shortcuts
        })
        idx = idx + 1
    end
    
    return data
end

function ActionAssetType:getExecuteFunction()
    return function(self, context, contextData)
        local commandId = self.load
        
        -- If load is a named command ID (string), convert to numeric
        if type(commandId) == "string" then
            commandId = reaper.NamedCommandLookup('_'..commandId)
            if commandId == 0 then
                self.context.logger:logError('Named command not found: ' .. self.load)
                return false
            end
        end
        
        r.Main_OnCommand(commandId, 0)
        return true
    end
end

function ActionAssetType:assembleAsset(action)
    -- Use named command ID if available, otherwise use numeric ID
    local actionId = action.namedId and action.namedId ~= "" and action.namedId or action.numericId
    
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = actionId,
        searchText = { { text = action.name }, { text = action.prefix or '' } },
        group = self.group,
    })
    asset.shortcuts = action.shortcuts
    asset.numericId = action.numericId  -- Store for reference/debugging
    asset.namedId = action.namedId      -- Store for reference/debugging
    return asset
end
