-- @noindex
-- Action Asset Type Module

ActionAssetType = {}
ActionAssetType.__index = ActionAssetType
setmetatable(ActionAssetType, BaseAssetType)

ActionAssetType.new = BaseAssetType:createStandardConstructor("Actions", ASSETS.ACTION, ACTIONS_GROUP)

function ActionAssetType:getData()
    self.context.logger:logDebug('-- ActionAssetType:getData()')
    self.data = {}
    
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

        table.insert(self.data, {
            id = cmdId,
            order = idx,
            name = name,
            prefix = prefix,
            section = section,
            shortcuts = shortcuts
        })
        idx = idx + 1
    end
    
    self:logDataStats("actions", #self.data)
    return self.data
end

function ActionAssetType:getExecuteFunction()
    return function(self, context, contextData)
        r.Main_OnCommand(self.load, 0)
    end
end

function ActionAssetType:assembleAsset(action)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = action.id,
        searchText = { { text = action.name }, { text = action.prefix or '' } },
        group = self.group,
        order = action.order
    })
    asset.shortcuts = action.shortcuts
    return asset
end
