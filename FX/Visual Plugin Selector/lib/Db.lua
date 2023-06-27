-- @noindex
-- ! OD_Db
OD_VPS_DB = {
    filename = nil,
    paths = {},          -- paths to different files
    defaults = {},       -- defaults from reaper (like default fx filter)
    items = {            -- everything here will be persisted to a file
        fx_folders = {}, -- user defined fx folders
        plugins = {}     -- plugins
    },
    PLUGIN = {
        VARIANT_PATTERNS = {
            -- patterns in the plugin names that are actually variants of the same plugin.
            -- this is determined by the plugin developers, and is not always consistent.
            -- parantheses are there to mark which part of the name should be captured as the variant.
            '%(?(mono)%)?', '%(?(stereo)%)?', '%(?(mono/stereo)%)?', '%(?(stereo/%d%.%d)%)?', '(upmix %dto%d)', '%(([ms])%)', '%((.-%->.+)%)' },
        VENDOR_ALIASES = {
            -- some vendors have different names in different plugin types.
            ['Universal Audio'] = { 'Universal Audio, Inc.', 'Universal Audio' },
            ['Native Instruments'] = { 'Native Instruments GmbH', 'Native Instruments' },
        },
        PHOTO_PRIORITY = {
            -- determins which plugin type should be preffered when taking a screenshot of a plugin.
            ['VST3'] = 10,
            ['VST2'] = 5,
            ['AU'] = 3,
            ['JS'] = 2,
        }
    }
}

function OD_VPS_DB:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- set paths to ini files
function OD_VPS_DB:init()
    if r.x64 then
        self.paths.vst = r.path .. (OS_is.mac_arm and "/reaper-vstplugins_arm64.ini" or "/reaper-vstplugins64.ini")
        if OS_is.mac then
            self.paths.au = r.path .. (OS_is.mac_arm and "/reaper-auplugins_arm64.ini" or "/reaper-auplugins64.ini")
        end
    else
        self.paths.vst = r.path .. "/reaper-vstplugins.ini"
        if OS_is.mac then
            self.paths.au = r.path .. "/reaper-auplugins.ini"
        end
    end
    self.paths.fx_folders = r.path .. "/reaper-fxfolders.ini"
    if self.filename == nil then error("DB filename not set") end
end

function OD_VPS_DB:helpers()
    local self = self
    local helpers = {
        findContentKey = function(content, key) -- adapted from Quick Adder 2 by neutronic
            content = content:match(key .. "[:=].-\n")
            if not content and key:match("vstpath") then
                content = OS_is.win and
                    (r.x64 and os.getenv("ProgramFiles(x86)") .. "\\vstplugins;" or "") ..
                    os.getenv("ProgramFiles") .. "\\vstplugins;" ..
                    os.getenv("CommonProgramFiles") .. "\\VST3\n" or
                    OS_is.mac and
                    "/Library/Audio/Plug-Ins/VST;/Library/Audio/Plug-Ins/VST3;" ..
                    os.getenv("HOME") .. "/Library/Audio/Plug-Ins/VST;" ..
                    os.getenv("HOME") .. "/Library/Audio/Plug-Ins/VST3\n"
            end
            return content and content:gsub(key .. "[:=]%s?", "") or false
        end,
        -- get default fx filter, as defined in reaper settings -> Plug-ins -> Only show FX matching filter string
        parseIniFxFilt = function(str)                        -- adapted from Quick Adder 2 by neutronic
            if not str then str = 'NOT ( ^AU "(Waves)" )' end --if it's not there, it means that the default is set, which is this
            if str:match(" OR ") then return end
            str = str:gsub("AND", "")
            str = str:gsub("\"", "")
            local tbl = { excl = {}, incl = {} }
            for match in str:gmatch("NOT %( .- %)%s?") do
                local match_ins = match:match("NOT %( (.+ )%)")
                if match_ins:match("NOT") then return end
                local tbl2 = {}
                for phrase in match_ins:gmatch("%(.-%)%s") do
                    table.insert(tbl2, phrase:match("(%(.-%))%s"):lower())
                    match_ins = match_ins:gsub(OD_MagicFix(phrase), "")
                end
                for word in match_ins:gmatch(".-%s") do
                    table.insert(tbl2, word:match("(.-)%s"):lower())
                end
                table.insert(tbl.excl, tbl2)
                str = str:gsub(OD_MagicFix(match), "")
            end
            for match in str:gmatch("NOT .-%s") do
                local match_ins = match:match("NOT (.-%s)")
                if match_ins == "(" then return end
                local tbl2 = {}
                for word in match_ins:gmatch(".-%s") do
                    table.insert(tbl2, word:match("(.-)%s"):lower())
                end
                table.insert(tbl.excl, tbl2)
                str = str:gsub(OD_MagicFix(match), "")
            end

            for match in str:gmatch("%( .- %)%s") do
                table.insert(tbl.incl, match:match("%( (.+ )%)"):lower())
                str = str:gsub(OD_MagicFix(match), "")
            end

            for match in str:gmatch("%(.-%)%s") do
                table.insert(tbl.incl, { match:match("%(.+%)"):lower() })
                str = str:gsub(OD_MagicFix(match), "")
            end

            for match in str:gmatch(".-%s") do
                local match_ins = match:match("(.-)%s")
                if match_ins == "" then goto SKIP end
                table.insert(tbl.incl, { match:match("(.-)%s"):lower() })
                ::SKIP::
            end
            self.defaults.fx_filter = tbl
        end,
        parseIniFxFodlers = function(fx_folders_ini) -- adapted from Quick Adder 2 by neutronic
            if fx_folders_ini then
                fx_folders_ini = fx_folders_ini .. "\n\n"
                local folder_names = fx_folders_ini:match("%[Folders%](.-)\n[\n%[]")
                if folder_names then
                    self.items.fx_folders = {}
                    for match in folder_names:gmatch("Name%d+=.-\n") do
                        local n, name = match:match("Name(%d+)=(.+)\n")
                        self.items.fx_folders[n + 1] = { name = name }
                    end

                    for match in fx_folders_ini:gmatch("(Folder%d+%].-)\n[\n%[]") do
                        local n, content = match:match("Folder(%d+)%](.+)")
                        self.items.fx_folders[n + 1].content = content:gsub("[^%w%.\n\r]", "_"):lower()
                    end
                    fx_folders_ini = nil
                end
            end
        end,
        fxExclCheck = function(str, include) -- adapted from Quick Adder 2 by neutronic
            if not str then return end
            if include and #self.defaults.fx_filter.incl == 0 then return true end
            if not include and #self.defaults.fx_filter.excl == 0 then return false end

            local tbl = include and self.defaults.fx_filter.incl or self.defaults.fx_filter.excl
            for i = 1, #tbl do
                local pass = nil
                for n = 1, #tbl[i] do
                    local str2 = OD_MagicFix(tbl[i][n])
                    local str2 = str2:gsub("%%^", "^")
                    if n == #tbl[i] and (n == 1 or pass) and str:match(str2) then
                        return true
                    elseif str:match(str2) then
                        pass = true
                    elseif not str:match(str2) then
                        goto SKIP
                    end
                end
                ::SKIP::
            end
        end,
        getFXfolder = function(str, type_n) -- adapted from Quick Adder 2 by neutronic
            str = str:lower()
            local fx_folder = ""

            if not str then return fx_folder end

            if type_n == 3 then -- if VST
                local vst_id, vst_file = str:match("(.-)//(.+)")
                vst_id = vst_id:gsub("{%w+", "")

                for i = 1, self.items.fx_folders and #self.items.fx_folders or 0 do
                    if self.items.fx_folders[i].content and (vst_id ~= "0" and self.items.fx_folders[i].content:find(vst_id) or
                            self.items.fx_folders[i].content:find(vst_file .. "[\n\r]")) then
                        fx_folder = fx_folder .. "\t" .. self.items.fx_folders[i].name
                    end
                end
            else
                str = str:gsub("[^%w%.\n\r]", "_")

                -- ? instead of OD_EscapePattern maybe should use OD_MagicFix from Quick Adder 2
                for i = 1, self.items.fx_folders and #self.items.fx_folders or 0 do
                    if self.items.fx_folders[i].content and self.items.fx_folders[i].content:match("item%d+_" .. OD_EscapePattern(str)) then
                        local fx_n = self.items.fx_folders[i].content:match("item(%d+)_" .. OD_EscapePattern(str))

                        if self.items.fx_folders[i].content:find("type" .. fx_n .. "_" .. type_n) then
                            fx_folder = fx_folder .. "\t" .. self.items.fx_folders[i].name
                        end
                    end
                end
            end

            return fx_folder
        end
    }

    return helpers
end

function OD_VPS_DB:parseIniFiles()
    self:helpers().parseIniFxFodlers(OD_GetContent(self.paths.fx_folders))
    self.defaults.fx_filter_string = self:helpers().findContentKey(r.ini,
        r.x64 and (OS_is.win and "def_fx_filt64" or "def_fx_filtx64") or
        OS_is.win and "def_fx_filt32" or "def_fx_filtx32")
    self:helpers().parseIniFxFilt(self.defaults.fx_filter_string)
end

function OD_VPS_DB:load()
    if not OD_FileExists(self.filename) then error("File not found: " .. self.filename) end
    self.items = table.load(self.filename)
end

function OD_VPS_DB:save()
    table.save(self.items, self.filename)
end

function OD_VPS_DB:scanPhotos()
    -- iterates through plugin.instances, and selects the instance whose fx_type has the highest priority in PHOTO_PRIORITY
    local function selectInstance(plugin)
        local chosen_instance = nil
        local highest_priority = 0
        for i, instance in ipairs(plugin.instances) do
            if instance.fx_type then
                local priority = self.PLUGIN.PHOTO_PRIORITY[instance.fx_type]
                if priority and priority > highest_priority then
                    chosen_instance = instance
                    highest_priority = priority
                end
            end
        end
        return chosen_instance
    end

    local path = self.app.settings.current.photosPath
    r.RecursiveCreateDirectory(path, 0)
    local cntr = 0
    for key, plugin in OD_PairsByOrder(self.items.plugins) do
        local instance = selectInstance(plugin)
        -- if key == 'fabfilter_pro-c 2' then 
        local targetFilename = self.app.settings.current.photosPath:gsub('\\', '/'):gsub('/$', '') .. '/' ..
            key .. '.jpg'
        local file_exists = OD_FileExists(targetFilename)
        -- if file wasn's scanned yet, haven't crashed or if it was scanned but the image file doesn't exist
        if (plugin.photo and not file_exists) or (not plugin.scanned and not plugin.crashed) then
            if file_exists and plugin.photo == nil then -- file already exists for plugin, but it hasn't been scanned
                self.app.logger:logInfo(('Capture found: %s'):format(instance.full_name), targetFilename)
                plugin.photo = targetFilename
                plugin.scanned = true
                plugin.loaded = true
                plugin.crashed = false
            else
                local loadString = instance.fx_type:gsub('VST2', 'VST') ..
                    (instance.instrument and 'i:' or ':') .. instance.full_name
                plugin.crashed = true
                self:save()
                local success, track, window = LoadPlugin(loadString)
                plugin.crashed = false
                OD_WaitAndDo(self.app.settings.current.vendorWaitTimes[instance.vendor] or 0.5, function() -- some plugins need time to load the ui 
                    coroutine.yield()
                end, true)
                plugin.scanned = true
                if not success then
                    self.app.logger:logError('Error loading plugin: ' .. loadString)
                else
                    CapturePluginWindow(window, targetFilename)
                    if OD_FileExists(targetFilename) then
                        self.app.logger:logInfo(('Capture succeeded: %s'):format(instance.full_name), targetFilename)
                        plugin.loaded = true
                        plugin.photo = targetFilename
                    else
                        self.app.logger:logError(('Capture failed: %s'):format(instance.full_name), targetFilename)
                        plugin.loaded = false
                        plugin.photo = nil
                    end
                end
                r.DeleteTrack(track)
            end
        end
        cntr = cntr + 1
        -- if cntr % 20 == 0 then
        --     -- reaper.ShowConsoleMsg(cntr..'\n')
        --     coroutine.yield()
        -- end
    end
    self:save()
end

function OD_VPS_DB:scan(scan_photos)
    self.items.plugins = {}
    self.app.temp.scanTotal = 0
    self:parseIniFiles()
    self:getVst()
    self:getAu()
    self:save()
    if scan_photos then self:scanPhotos() end
end

-- adapted from Quick Adder 2 by neutronic
-- function OD_VPS_DB:getJS()
--     local tbl = {}
--     local cntr = 0
--     local file_list = getFiles("Effects")
--     for i = 1, #file_list do
--         local js_name
--         local content = OD_GetContent(file_list[i])

--         for l in content:gmatch(".-[\n\r]") do
--             if l:match("^desc:.+") then
--                 js_name = l:match("^desc:%s*(.+)[\n\r]")
--                 break
--             end
--         end

--         if js_name then
--             local path = file_list[i]:gsub(".+/Effects/", "")

--             if rpr.def_fx_filt and fxExclCheck("js:" .. js_name:lower()) then goto SKIP end
--             if rpr.def_fx_filt and not fxExclCheck("js:" .. js_name:lower(), true) then goto SKIP end
--             local fx_folder = getFXfolder(path, 2)

--             cntr = cntr + 1
--             if select(2, math.modf(cntr / 10)) == 0 then
--                 coroutine.yield(#tbl)
--             end

--             table.insert(tbl, "JS:" .. js_name .. fx_folder .. "|,|" .. path .. "|,||,||,|")
--         end
--         ::SKIP::
--     end
-- end

-- adapted from Quick Adder 2 by neutronic
function OD_VPS_DB:getAu()
    local cntr = 0
    local content = OD_GetContent(self.paths.au)
    if not content then return end
    for line in content:gmatch(".-[\n\r]") do
        -- if cntr > 100 then goto SKIP end
        if line:match("^.-=.+$") then
            local au_name, au_i = line:match("^(.-)%s-=(.+)$")
            au_i = au_i:match("<inst") ~= nil
            if not au_name:match("^#") then
                local fx_folder = self:helpers().getFXfolder(au_name, 5)
                self:addPlugin(au_name, 'AU', fx_folder, au_i, nil)
                cntr = cntr + 1
                if cntr % 20 == 0 then
                    coroutine.yield()
                end
            end
        end
        ::SKIP::
    end
end

-- adapted from Quick Adder 2 by neutronic
function OD_VPS_DB:getVst()
    local cntr = 0
    local content = OD_GetContent(self.paths.vst)
    for line in content:gmatch(".-\n") do
        -- if cntr > 100 then goto SKIP end
        if not line:match(".-=.-,.-,.+") then goto SKIP end -- if not valid FX entry
        local fx_type
        local vst_file, vst_id, vst_name = line:match("(.-)=.-,(.-),(.+)\n")
        vst_file = vst_file:gsub("<.+", "")

        if vst_name:match("^[#<]") then goto SKIP end -- if exclude or shell

        local vsti = vst_name:match("!!!VSTi$") ~= nil

        if vsti then vst_name = vst_name:gsub("!!!VSTi", "") end

        if not vst_file:lower():match("%.vst3$") then -- if VST2
            fx_type = "VST2"
        else
            fx_type = "VST3"
        end
        local fx_folder = self:helpers().getFXfolder(vst_id .. "//" .. vst_file, 3)

        self:addPlugin(vst_name, fx_type, fx_folder, vsti, vst_id)
        cntr = cntr + 1
        if cntr % 20 == 0 then
            coroutine.yield()
        end
        ::SKIP::
    end
end

function OD_VPS_DB:addPlugin(full_name, fx_type, fx_folder, instrument, vst_id)
    local self = self
    local function shouldExclude()
        return (self.defaults.fx_filter and self:helpers().fxExclCheck(fx_type:upper():gsub("VST2", "VST") .. (instrument and 'i' or '') .. ":" .. full_name:lower())) or
            (self.defaults.fx_filter and not self:helpers().fxExclCheck(fx_type:upper():gsub("VST2", "VST") .. (instrument and 'i' or '') .. ":" .. full_name:lower(), true))
    end

    local function extractNameVendorChannels(full_name, fx_type)
        local name, vendor, channels, variant
        local t = {}
        if fx_type:match('^AU') then
            t[2], t[1] = full_name:match('(.-): (.*)')
            name = t[1]
        elseif fx_type:match('^VST') then
            local counter = 1
            for w in string.gmatch(full_name, "%b()") do
                t[counter] = w:match("%((.+)%)")
                counter = counter + 1
            end
        end
        vendor = t[#t]

        if #t == 0 then return false end

        if t[#t]:match('.-%dch$') or t[#t]:match('%d*%sout$') or t[#t] == 'mono' then
            channels = t[#t]
            vendor = t[#t - 1]
        end

        if fx_type:match('^VST') then
            name = full_name:gsub(' %(' .. OD_EscapePattern(vendor) .. '%).-$', '')
        end

        --  some vendors appear differently on different formats, so I try to unify them
        for k, v in pairs(self.PLUGIN.VENDOR_ALIASES) do
            if OD_HasValue(v, vendor) then
                vendor = k
                break
            end
        end
        
        for i, varPat in ipairs(self.PLUGIN.VARIANT_PATTERNS) do
            if name:lower():match('%s' .. varPat:lower() .. '$') then
                local pat = OD_CaseInsensitivePattern(varPat)
                variant = name:match('%s' .. pat .. '$')
                name = name:gsub('%s' .. pat .. '$', '')
                break
            end
        end

        return true, name, vendor, channels, variant
    end

    local function duplicatesExist(instances, fx_type, name, vendor, variant, instrument, vst_id)
        -- check for duplicate type(+instrument)+name
        for i, v in ipairs(instances) do
            if (v.name == name) and (v.variant == variant) and (v.vendor == vendor) and (v.fx_type == fx_type) and (v.instrument == instrument) then
                return true, 'Duplicate vst name and type found', fx_type .. (instrument and 'i:' or ': ') .. full_name
            end
        end
        if vst_id then
            -- check for duplicate IDs - waves plugins are sometimes installed with multiple waveshells that share the same ID
            -- no need to worry about it here, so leave just one. Reaper deals with it when loading the FX
            for i, v in ipairs(instances) do
                if v.vst_id == vst_id then
                    return true, 'Duplicate vst ID found', vst_id
                end
            end
        end
        return false
    end

    if full_name == '' then return false end

    if shouldExclude() then
        self.app.logger:logInfo('Skipping ' .. full_name .. ' - excluded by reaper FX filter',
            self.defaults.fx_filter_string)
        return false
    else
        local success, name, vendor, channels, variant = extractNameVendorChannels(full_name, fx_type)

        if not success then
            self.app.logger:logError('cannot parse plugin name: ' .. full_name)
            return false
        end

        local instanceInfo = {
            full_name = full_name,
            name = name,
            vendor = vendor,
            channels = channels,
            variant = variant,
            instrument = instrument,
            fx_type = fx_type,
            fx_folder = fx_folder,
            vst_id = vst_id
        }

        local key = (instrument and 'i_' or '') .. instanceInfo.vendor:lower() .. '_' .. instanceInfo.name:lower()
        if self.items.plugins[key] then
            local duplicatesExist, msg, msg_val = duplicatesExist(self.items.plugins[key].instances, fx_type, name,
                vendor, variant, instrument, vst_id)
            if duplicatesExist then
                self.app.logger:logInfo('Skipping ' .. full_name .. ' - ' .. msg, msg_val)
            else
                table.insert(self.items.plugins[key].instances, instanceInfo)
                self.app.logger:logInfo(
                    'Added ' .. fx_type .. (instrument and 'i' or '') .. ' variant to: ' .. name .. ' by ' .. vendor,
                    instanceInfo.full_name)
            end
        else
            self.app.temp.scanTotal = self.app.temp.scanTotal + 1
            self.items.plugins[key] = {
                name = name,
                vendor = vendor,
                order = self.app.temp.scanTotal,
                instances = { instanceInfo },
                photo = nil, -- filename of photo of the plugin
                scanned = false, -- was the plugin scanned for a photo?
                loaded = nil, -- when loading during photo scanning, was it loaded successfully?
                crashed = false, -- when loading during photo scanning, did it crash reaper
            }
            self.app.logger:logInfo('Added ' ..
                fx_type .. (instrument and 'i' or '') .. ': ' .. name .. ' by ' .. vendor, instanceInfo.full_name)
        end
        return true
    end
end
