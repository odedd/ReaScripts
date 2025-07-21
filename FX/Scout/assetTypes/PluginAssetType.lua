-- @noindex
-- Plugin Asset Type Module

PluginAssetType = {}
PluginAssetType.__index = PluginAssetType
setmetatable(PluginAssetType, BaseAssetType)

PluginAssetType.new = BaseAssetType:createStandardConstructor("FX")

function PluginAssetType:getData()
    local function addPlugin(full_name, fx_type, instrument, ident)
        -- Plugin parsing and adding logic
        self.context.logger:logDebug('-- addPlugin()')

        local function extractNameVendor(full_name, fx_type)
            self.context.logger:logDebug('-- addPlugin() -> extractNameVendor()')
            local name, vendor
            local t = {}

            self.context.logger:logDebug('Parsing:', full_name)
            name = (fx_type == 'Internal') and full_name or full_name:match(fx_type .. ': (.*)$')
            if not fx_type:match('^JS') and fx_type ~= 'Internal' and fx_type ~= 'ReWire' then
                local counter = 1
                for w in string.gmatch(full_name, "%b()") do
                    t[counter] = w:match("%((.-)%)$")
                    counter = counter + 1
                end
            end
            vendor = t[#t]

            if vendor == nil and name == nil and (#t == 0) then return false end
            if not fx_type:match('^JS') then
                if fx_type ~= 'Internal' and fx_type ~= 'ReWire' then
                    if next(t) ~= nil and (tostring(t[#t]):match('.-%dch$') or tostring(t[#t]):match('%d*%sout$') or tostring(t[#t]) == 'mono') then
                        vendor = t[#t - 1]
                    end
                    name = vendor and name:gsub(' %(' .. OD_EscapePattern(vendor) .. '%).-$', '') or name
                end
            end
            if vendor ~= '' and vendor ~= nil then
                self.context.fxDevelopers = self.context.fxDevelopers or {}
                self.context.fxDevelopers[vendor] = true
            end
            return true, name, (vendor == '' and nil or vendor)
        end

        if full_name == '' then return false end

        local success, name, vendor = extractNameVendor(full_name, fx_type)

        if success then
            self.context.logger:logDebug('Parsing successful')
            self.context.logger:logDebug('Name', name)
            self.context.logger:logDebug('Vendor', vendor)
        else
            self.context.logger:logError('Cannot parse plugin name', full_name)
            return false
        end

        local plugin = {
            full_name = full_name,
            fx_type = fx_type,
            name = name,
            vendor = vendor,
            ident = ident,
        }
        table.insert(self.data, plugin)
        self.context.logger:logDebug('Added ' ..
            fx_type .. (instrument and 'i' or '') .. ': ' .. name .. (vendor and (' by ' .. vendor) or ''),
            full_name)
        return plugin
    end

    self.data = {}
    local i = 0
    while true do
        local found, name, ident = reaper.EnumInstalledFX(i)
        if not found then break end

        local fx_type = name:match('(.-):%s') or 'Internal'
        local instrument = fx_type:sub(-1) == 'i'
        local plugin = addPlugin(name, fx_type, instrument, ident)
        if plugin then
            plugin.group = plugin.fx_type
        end
        i = i + 1
    end
    return self.data
end

function PluginAssetType:getExecuteFunction()
    return function(self, context, contextData, confirm)
        if context == RESULT_CONTEXT.MAIN then
            local tracks = self.context.db:getSelectedTracks()
            if #tracks > self.context.settings.current.numberOfTracksThatRequireConfirmation and confirm ~= true then
                self.context.temp.confirmMultipleTracks = {
                    count = #tracks,
                    resultContext = context,
                    contextData = contextData
                }
                -- Return false for confirmation dialog - user hasn't confirmed yet, so don't add to recents
                return false
            else
                local numTracks = r.CountSelectedTracks2(0, true);
                if numTracks == 0 then return false, 'No tracks selected' end
                for i = 0, numTracks - 1 do
                    local track = r.GetSelectedTrack2(0, i, true)
                    local fxIndex = r.TrackFX_AddByName(track, self.load, false, -1)
                end
                return true, ('Added %s to %d tracks'):format(self.searchText[1].text, numTracks)
            end
        elseif context == RESULT_CONTEXT.ALT then
            local numItems = r.CountMediaItems(0)
            if numItems == 0 then return false end

            for i = 0, numItems - 1 do
                local item = r.GetMediaItem(0, i)
                if r.IsMediaItemSelected(item) then
                    local take = r.GetActiveTake(item)
                    if take then
                        r.TakeFX_AddByName(take, self.load, 1)
                    end
                end
            end
            -- Always return true for ALT context - user attempted to add to takes
            -- (regardless of whether there were selected items or takes)
            return true, ('Added %s to %d items'):format(self.searchText[1].text, numItems)
        end

        -- Default return for other contexts
        return false
    end
end

function PluginAssetType:assembleAsset(plugin)
    if not self.context.settings.current.fxTypeVisibility[plugin.fx_type] then
        return nil
    end

    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = plugin.ident,
        searchText = { { text = plugin.name }, { text = plugin.vendor or '' } },
        group = plugin.group,
        order = 0
    })

    asset.vendor = plugin.vendor
    asset.fx_type = plugin.fx_type
    asset.categories = {}
    asset.folders = {}

    asset.isInCategory = function(self, categoryName)
        if self.categories[categoryName] ~= nil then
            return self.categories[categoryName]
        end
        local path, file, ext = OD_DissectFilename(self.load)
        local categoryPluginID = (file .. '.' .. ext):gsub('[ -]', '_')

        if self.context.pluginToCategories[categoryPluginID] then
            self.categories[categoryName] = OD_HasValue(self.context.pluginToCategories[categoryPluginID], categoryName)
        else
            self.categories[categoryName] = false
        end
        return self.categories[categoryName]
    end

    asset.isInFolder = function(self, folderId)
        if self.folders[folderId] ~= nil then
            return self.folders[folderId]
        end

        if self.context.pluginToFolders[self.load] then
            self.folders[folderId] = OD_HasValue(self.context.pluginToFolders[self.load], folderId)
        else
            self.folders[folderId] = false
        end
        return self.folders[folderId]
    end

    return asset
end
