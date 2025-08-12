-- @noindex
-- Plugin Asset Type Module

PluginAssetType = {}
PluginAssetType.__index = PluginAssetType
setmetatable(PluginAssetType, BaseAssetType)

local helpers = dofile(Scr.dir .. 'AssetTypes/AssetTypeHelpers.lua')
function PluginAssetType.new(class, context)
    local instance = BaseAssetType:createStandardConstructor("FX")(class, context)
    -- Plugins are file-based assets (have file paths)
    instance.shouldMapBaseFilenames = true
    instance.trackAddDate = true
    instance.allowInQuickChain = true
    instance = helpers.addPluginActions(instance)
    instance.magicWord = 'F'
    return instance
end

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

            local vendorBaseName = vendor or ''
            local variant, variantPat, variantOrder
            if vendor then
                --  some vendors appear differently on different formats, so I try to unify them
                for k, v in pairs(PLUGIN.VENDOR_ALIASES) do
                    if OD_HasValue(v, vendor) then
                        vendorBaseName = k
                        break
                    end
                end
            end

            local baseName = nil
            local variants = {}
            local variantPat = nil
            local variantOrder = nil

            for i, varPat in ipairs(self.context.settings.current.variantMatchingOrder) do
                if (full_name:lower()):match('%s' .. varPat:lower()) then
                    local baseNameCandidate = name:match('(.*)%s' .. OD_CaseInsensitivePattern(varPat))
                    if baseNameCandidate then baseName = baseNameCandidate end
                    for var in full_name:gmatch('%s' .. OD_CaseInsensitivePattern(varPat)) do
                        if variantPat == nil then
                            variantPat = varPat
                            variantOrder = i
                        end
                        table.insert(variants, var)
                    end
                end
            end
            baseName = baseName or name
            variant = table.concat(variants, '|')

            return true, name, (vendor ~= '' and vendor or nil), baseName,
                (vendorBaseName ~= '' and vendorBaseName or nil), variant, variantPat, variantOrder
        end

        if full_name == '' then return false end

        local success, name, vendor, baseName, vendorBaseName, variant, variantPat, variantOrder = extractNameVendor(
            full_name, fx_type)
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
            baseName = baseName,
            vendor = vendor,
            vendorBaseName = vendorBaseName,
            variant = variant,
            variantPat = variantPat,
            variantOrder = variantOrder,
            instrument = instrument,
            ident = ident
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

function PluginAssetType:assembleAsset(plugin)
    local asset = self:createAssetBase({
        type = self.assetTypeId,
        load = plugin.ident,
        searchText = { { text = plugin.baseName } },
        group = plugin.group,
    })

    if plugin.vendor and plugin.vendor ~= '' then table.insert(asset.searchText, { text = plugin.vendor or '' }) end
    if plugin.variant then table.insert(asset.searchText, { text = plugin.variant }) end
    asset.name = plugin.name
    asset.baseName = plugin.baseName
    asset.vendorBaseName = plugin.vendorBaseName
    asset.vendor = plugin.vendor
    asset.instrument = plugin.instrument
    asset.fx_type = plugin.fx_type
    asset.variant = plugin.variant
    asset.variantPat = plugin.variantPat
    asset.variantOrder = plugin.variantOrder
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
