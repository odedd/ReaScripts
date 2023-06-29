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
            '%(?(mono)%)?', '%(?(stereo)%)?', '%(?(mono/stereo)%)?', '%(?(stereo/%d%.%d)%)?', '%(?(mono/%d%.%d)%)?',
            '%(?(%d%.%d/%d%.%d)%)?',
            '(upmix %dto%d)', '%(([ms])%)', '%((.-%->.+)%)', '(5%.0)', '(5%.1)' },
        VENDOR_ALIASES = {
            -- some vendors have different names in different plugin types.
            ['iZotope'] = { 'iZotope, Inc.', 'iZotope' },
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
        loadPluginInstance = function(instance)
            local loadString = instance.fx_type:gsub('VST2', 'VST') ..
                ':' .. instance.full_name
            local windowTitleString
            if instance.fx_type == 'AU' then
                windowTitleString = 'AU' ..
                    (instance.instrument and 'i: ' or ': ') ..
                    instance.full_name:gsub('^' .. OD_EscapePattern(instance.originalVendor or instance.vendor) .. ':%s?', '') ..
                    (instance.vendor and (' (' .. (instance.originalVendor or instance.vendor) .. ')') or '')
            elseif instance.fx_type:match('^VST') then
                windowTitleString = instance.fx_type:gsub('VST2', 'VST') ..
                    (instance.instrument and 'i: ' or ': ') .. instance.full_name
            elseif instance.fx_type == 'JS' then
                windowTitleString = 'JS: ' .. instance.full_name
            else
                return false, nil, nil, 'Unknown plugin type'
            end

            self.app.logger:logDebug('Loading plugin instance using loadString', loadString)
            self.app.logger:flush()
            r.InsertTrackAtIndex(0, false)
            local track = r.GetTrack(0, 0)
            local fx = r.TrackFX_AddByName(track, loadString, false, -1)
            coroutine.yield() -- allow the plugin to load, otherwise when doing some of the next tests, some plugins crash
            if fx == -1 then 
                return false, track, nil, 'does not exist'
            end
            r.TrackFX_Show(track, fx, 3)
            local success = r.TrackFX_GetCount(track) > 0
            local hwnd
            local err
            --    reaper.defer()
            if success then
                self.app.logger:logDebug('Loading successful. Looking for window title', windowTitleString)
                hwnd = r.JS_Window_FindTop(windowTitleString, false) or
                r.JS_Window_FindTop(windowTitleString:gsub('^(.-):', '%1i:'), false) or --sometimes VST versions are loaded as VSTis, so look for that instead
                r.JS_Window_Find(windowTitleString, false) or                            --fallback to not finding the top window (useful as some plugins show a modal window on startup, which interrupts all following captures)
                r.JS_Window_Find(windowTitleString:gsub('^(.-):', '%1i:'), false)       --or    --fallback to non-top-VSTi same as above
                
                if not hwnd then
                    success = false
                    err = 'No hwnd'
                end
            else
                err = 'TrackFX_GetCount is 0'
            end
            return success, track, hwnd, err
        end,

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
        end,
        listDir = function(path) -- adapted from Quick Adder 2 by neutronic
            local dir_list = {}
            local i = 0
            while true do
                local dir = reaper.EnumerateSubdirectories(path, i)
                if not dir or dir:match(".+%.component")
                    or dir:match(".+%.vst%d?") then
                    break
                end
                local path = path .. "/" .. dir
                table.insert(dir_list, path)
                local subdir_list = self:helpers().listDir(path)
                for i = 1, #subdir_list do
                    table.insert(dir_list, subdir_list[i])
                end
                i = i + 1
            end
            return dir_list
        end,
        listJSFiles = function(dir_list) -- adapted from Quick Adder 2 by neutronic
            local cntr = 0
            local file_list = {}

            local getDirJSFiles = function(path)
                local file_list = {}
                local i = 0
                while true do
                    local path = not path:match("/$") and path .. "/" or path:match("/$") and path
                    local file = r.EnumerateFiles(path, i)

                    if not file then break end

                    if file:match("^.+jsfx$") or
                        (not file:match("%.") or file:match("%d%.%d")) then -- if JS
                        table.insert(file_list, path .. file)
                    end
                    i = i + 1
                end

                return file_list
            end

            for i = 1, #dir_list do
                local files = getDirJSFiles(dir_list[i])
                for i = 1, #files do
                    table.insert(file_list, files[i])
                end
            end

            return file_list
        end,
        getJSFiles = function(match) -- adapted from Quick Adder 2 by neutronic
            local file_list = {}
            local dir_list = {}
            local i = 0
            while true do
                local dir = reaper.EnumerateSubdirectories(r.path, i)
                if not dir then break end
                if dir:match("^" .. match .. (match and "$" or "")) then
                    local path = r.path .. "/" .. dir -- .. "/"
                    table.insert(dir_list, path)
                    local subdir_list = self:helpers().listDir(path)
                    for i = 1, #subdir_list do
                        table.insert(dir_list, subdir_list[i])
                    end
                end
                i = i + 1
            end

            file_list = self:helpers().listJSFiles(dir_list)
            return file_list
        end
    }

    return helpers
end

function OD_VPS_DB:parseIniFiles()
    self.app.logger:logDebug('-- OD_VPS_DB:parseIniFiles()')
    self:helpers().parseIniFxFodlers(OD_GetContent(self.paths.fx_folders))
    self.defaults.fx_filter_string = self:helpers().findContentKey(r.ini,
        r.x64 and (OS_is.win and "def_fx_filt64" or "def_fx_filtx64") or
        OS_is.win and "def_fx_filt32" or "def_fx_filtx32")
    self:helpers().parseIniFxFilt(self.defaults.fx_filter_string)
end

function OD_VPS_DB:load()
    self.app.logger:logDebug('-- OD_VPS_DB:load()')
    if not OD_FileExists(self.filename) then error("File not found: " .. self.filename) end
    self.items = table.load(self.filename)
end

function OD_VPS_DB:save()
    self.app.logger:logDebug('-- OD_VPS_DB:save()')
    table.save(self.items, self.filename)
end

function OD_VPS_DB:scanPhotos()
    self.app.logger:logInfo('-- OD_VPS_DB:scanPhotos()')
    -- iterates through plugin.instances, and selects the instance whose fx_type has the highest priority in PHOTO_PRIORITY
    local function selectInstance(plugin)
        self.app.logger:logDebug('-- OD_VPS_DB:scanPhotos() -> selectInstance()')
        local chosen_instance = nil
        local highest_priority = 0
        for i, instance in ipairs(plugin.instances) do
            if (not instance.missing) and instance.fx_type then
                local priority = self.PLUGIN.PHOTO_PRIORITY[instance.fx_type]
                if priority and priority > highest_priority then
                    chosen_instance = instance
                    highest_priority = priority
                end
            end
        end
        if chosen_instance then
            self.app.logger:logDebug('Instance chosen', '('..chosen_instance.fx_type .. ') ' ..chosen_instance.full_name)
        end
        return chosen_instance
    end
    -- tries to capture plugin photo, returns:
    -- 1. true if photo was captured or a capture already exists
    -- 2. true if retry is needed with another instance
    local function capturePluginPhoto(key, plugin)
        self.app.logger:logDebug('-- OD_VPS_DB:scanPhotos() -> capturePluginPhoto() plugin=', plugin.name)
        if plugin.onlyMissingInstances then 
            self.app.logger:logDebug('All plugin\'s instances are missing', plugin.name)
            return false, false
        end
        local instance = selectInstance(plugin)
        -- if key == 'fabfilter_pro-c 2' then
        local targetPath = self.app.settings.current.photosPath:gsub('\\', '/'):gsub('/$', '')
        local targetFilename = OD_SanitizeFilename(key .. '.jpg')
        local file_exists = OD_FileExists(targetPath .. '/' .. targetFilename)
        -- if file wasn's scanned yet, haven't crashed or if it was scanned but the image file doesn't exist
        if (not plugin.crashed) and ((not plugin.scanned) or (not plugin.photo) or (plugin.photo and not file_exists)) then
            if file_exists and plugin.photo == nil then -- file already exists for plugin, but it hasn't been scanned
                self.app.logger:logInfo(('Capture found: %s'):format(instance.full_name), targetPath ..
                    '/' .. targetFilename)
                plugin.photo = targetFilename
                plugin.scanned = true
                plugin.loaded = true
                plugin.crashed = false
                return true, false
            else
                plugin.crashed = true
                self:save()
                -- bring reaper's main window to the front and yield to let it get focus
                -- local mainHwnd = reaper.GetMainHwnd()
                -- reaper.JS_Window_SetForeground(mainHwnd)
                -- coroutine.yield()
                local success, track, window, err = self:helpers().loadPluginInstance(instance)
                plugin.crashed = false
                plugin.scanned = true
                local coordinates
                if err == 'No hwnd' then -- if no hwnd than it might have loaded as a dedicated process
                    local retval, x, y, w, h = GetExternalWindowCorrdinates(instance.name)
                    if retval then
                        success = true
                        err = false
                        coordinates = { x = x, y = y, w = w, h = h }
                    end
                end
                if not success then
                    self.app.logger:logError(
                        'Error loading plugin: ' .. instance.full_name .. ' (' .. instance.fx_type .. ')', err)
                    plugin.loaded = false
                    r.DeleteTrack(track)
                    if err == 'does not exist' then
                        self:deleteInstance(key, instance)
                        return false, true
                    else
                        return false, false
                    end
                else
                    -- some plugins need time to load the ui
                    plugin.loaded = true
                    OD_WaitAndDo(self.app.settings.current.vendorWaitTimes[instance.vendor] or 0.5, true,
                        function()
                            coroutine.yield()
                        end)
                    CapturePluginWindow(window, targetPath .. '/' .. targetFilename, coordinates)
                    if OD_FileExists(targetPath .. '/' .. targetFilename) then
                        self.app.logger:logInfo(('Capture succeeded: %s'):format(instance.full_name), targetFilename)
                        plugin.photo = targetFilename
                        r.DeleteTrack(track)
                        return true, false
                    else
                        self.app.logger:logError(
                            ('Capture failed: %s - plugin loaded but could not capture'):format(instance.full_name),
                            targetFilename)
                        plugin.photo = nil
                        r.DeleteTrack(track)
                        return false, false
                    end
                end
            end
        else
            if plugin.crashed then
                self.app.logger:logDebug('Capture skipped since plugin crashed before', instance.full_name)
                return false, false
            end
            self.app.logger:logDebug('Capture skipped since it already exists.', targetFilename)
            return true, false
        end
    end

    local path = self.app.settings.current.photosPath
    local totalSuccessfulCaptures = 0
    local totalFailedCaptures = 0
    local totalMissing = 0
    r.RecursiveCreateDirectory(path, 0)
    local cntr = 0
    for key, plugin in OD_PairsByOrder(self.items.plugins) do
        while not self.items.plugins[key].onlyMissingInstances do
            local success, retry = capturePluginPhoto(key, plugin)
            if success then
                totalSuccessfulCaptures = totalSuccessfulCaptures + 1
                break
            else
                if retry then
                    if self.items.plugins[key].onlyMissingInstances then
                        self.app.logger:logDebug('All plugin\'s instances are missing.', plugin.name)
                        totalMissing = totalMissing + 1
                        break
                    else
                        self.app.logger:logDebug('Retrying capture with a different instance.', plugin.name)
                    end
                else
                    totalFailedCaptures = totalFailedCaptures + 1
                    break
                end
            end
        end
        -- if self.items.plugins[key].onlyMissingInstances then totalFailedCaptures = totalFailedCaptures + 1 end
        cntr = cntr + 1
    end
    self:save()
    self.app.logger:logInfo('Scan complete')
    self.app.logger:logInfo('Total plugins scanned ', cntr)
    self.app.logger:logInfo('Total captured or already existing ', totalSuccessfulCaptures)
    self.app.logger:logInfo('Total failed captures ', totalFailedCaptures)
    self.app.logger:logInfo('Total missing plugins ', totalMissing)
    return totalSuccessfulCaptures, totalFailedCaptures, totalMissing
end

-- if hard_delete is true, it will delete the plugin instance, otherwise it will just mark it as missing
-- if the plugin has no instances left, it will either delete the plugin key (if hard_delete=true) or mark it as having only missing instances
function OD_VPS_DB:deleteInstance(key, instance, hard_delete)
    local plugin = self.items.plugins[key]
    local allMissing = true
    for i = 1, #plugin.instances do
        if OD_TableDeepCompare(plugin.instances[i], instance) then
            if hard_delete then
                self.app.logger:logDebug('Deleting instance', plugin.instances[i].full_name)
                table.remove(plugin.instances, i)
                break
            else
                self.app.logger:logDebug('Marking instance as missing', plugin.instances[i].full_name)
                plugin.instances[i].missing = true
            end
        end
        if not plugin.instances[i].missing then
            allMissing = false
        end
    end
    if hard_delete then -- if set to true, delete the key
        if OD_IsTableEmpty(plugin.instances) then
            self.app.logger:logInfo('Deleting plugin key - no more instances', key)
            if plugin.photo then
                local photoFullPath = self.app.settings.current.photosPath:gsub('\\', '/'):gsub('/$', '') ..
                    '/' .. plugin.photo
                if OD_FileExists(photoFullPath) then
                    local success = os.remove(photoFullPath)
                    if success then
                        self.app.logger:logDebug('Deleted photo', photoFullPath)
                    else
                        self.app.logger:logError('Failed to delete photo', photoFullPath)
                    end
                end
            end
            self.items.plugins[key] = nil
        end
    elseif allMissing then -- mark the key as having only missing instances
        self.app.logger:logInfo('Mark key as having only missing instances', key)
        self.items.plugins[key].onlyMissingInstances = true
    end
end

function OD_VPS_DB:scan(scan_photos)
    self.app.logger:logInfo('-- OD_VPS_DB:scan()')
    local self = self

    -- adapted from Quick Adder 2 by neutronic
    local function getAu()
        self.app.logger:logInfo('-- OD_VPS_DB:scan() -> getAu()')
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
                    self:addPlugin(au_name, 'AU', fx_folder, au_i)
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
    local function getVst()
        self.app.logger:logInfo('-- OD_VPS_DB:scan() -> getVst()')
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

            self:addPlugin(vst_name, fx_type, fx_folder, vsti, { vst_id = vst_id })
            cntr = cntr + 1
            if cntr % 20 == 0 then
                coroutine.yield()
            end
            ::SKIP::
        end
    end

    --adapted from Quick Adder 2 by neutronic
    local function getJS()
        self.app.logger:logInfo('-- OD_VPS_DB:scan() -> getJS()')
        local tbl = {}
        local cntr = 0
        local file_list = self:helpers().getJSFiles("Effects")
        for i = 1, #file_list do
            local js_name
            local js_author
            local content = OD_GetContent(file_list[i])
            local contentFound = 0
            for l in content:gmatch(".-[\n\r]") do
                if l:match("^desc:.+") then
                    js_name = l:match("^desc:%s*(.+)[\n\r]")
                end
                if l:match("^author:.+") then
                    js_author = l:match("^author:%s*(.+)[\n\r]")
                end
                if contentFound == 2 then break end
            end
            if js_name then
                local path = file_list[i]:gsub(".+/Effects/", "")
                local fx_folder = self:helpers().getFXfolder(path, 2)
                self:addPlugin(js_name, 'JS', fx_folder, false, { vendor = js_author, path = path })
                cntr = cntr + 1
                if cntr % 20 == 0 then
                    coroutine.yield()
                end
            end
        end
    end

    local function deleteUnscanned()
        self.app.logger:logInfo('-- OD_VPS_DB:deleteUnscanned()')
        for key, plugin in OD_PairsByOrder(self.items.plugins) do
            if not self.app.temp.scanned_instances[key] then -- if whole key (plugin+vendor) wasn't found, delete it
                self.items.plugins[key] = nil
            else
                for i = 1, #plugin.instances do
                    local foundInstance = false
                    for j = 1, #self.app.temp.scanned_instances[key] do
                        if OD_TableDeepCompare(plugin.instances[i], self.app.temp.scanned_instances[key][j]) then
                            foundInstance = true
                        end
                    end
                    if not foundInstance then
                        self:deleteInstance(key, plugin.instances[i], true)
                        -- self.app.logger:logInfo('Deleting instance', plugin.instances[i].full_name)
                        -- table.remove(plugin.instances, i)
                    end
                end
            end
        end
    end

    self.app.temp.scanTotal = 0
    self.app.temp.scanned_instances = {} -- mark all plugins that were scanned so that I can delete the ones that weren't
    self:parseIniFiles()
    getVst()
    getAu()
    getJS()
    deleteUnscanned()
    self:save()
    if scan_photos then self:scanPhotos() end
end

function OD_VPS_DB:addPlugin(full_name, fx_type, fx_folder, instrument, args)
    self.app.logger:logDebug('-- OD_VPS_DB:addPlugin()')
    local self = self
    args = args or {}
    local vst_id = args.vst_id

    local function shouldExclude()
        self.app.logger:logDebug('-- OD_VPS_DB:addPlugin() -> shouldExclude()')
        return (self.defaults.fx_filter and self:helpers().fxExclCheck(fx_type:lower():gsub("vst2", "vst") .. (instrument and 'i' or '') .. ":" .. full_name:lower())) or
            (self.defaults.fx_filter and not self:helpers().fxExclCheck(fx_type:lower():gsub("vst2", "vst") .. (instrument and 'i' or '') .. ":" .. full_name:lower(), true))
    end

    local function extractNameVendorChannels(full_name, fx_type)
        self.app.logger:logDebug('-- OD_VPS_DB:addPlugin() -> extractNameVendorChannels()')
        local name, vendor, channels, variant
        local t = {}
        if fx_type:match('^JS') then
            vendor = args.vendor
            name = full_name
        elseif fx_type:match('^AU') then
            t[2], t[1] = full_name:match('(.-):%s?(.*)')
            name = t[1]
        elseif fx_type:match('^VST') then
            local counter = 1
            for w in string.gmatch(full_name, "%b()") do
                t[counter] = w:match("%((.+)%)")
                counter = counter + 1
            end
        end
        vendor = vendor or t[#t]

        if (fx_type ~= 'JS') and (#t == 0) then return false end

        if not fx_type:match('^JS') and (t[#t]:match('.-%dch$') or t[#t]:match('%d*%sout$') or t[#t] == 'mono') then
            channels = t[#t]
            vendor = t[#t - 1]
        end

        if fx_type:match('^VST') then
            name = full_name:gsub(' %(' .. OD_EscapePattern(vendor) .. '%).-$', '')
        end
        local originalVendor
        if vendor then
            --  some vendors appear differently on different formats, so I try to unify them
            for k, v in pairs(self.PLUGIN.VENDOR_ALIASES) do
                if OD_HasValue(v, vendor) then
                    originalVendor = vendor
                    vendor = k
                    break
                end
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

        return true, name, vendor, originalVendor, channels, variant
    end

    local function duplicatesExist(instances, instance)
        self.app.logger:logDebug('-- OD_VPS_DB:addPlugin() -> duplicatesExist()')
        -- check for duplicate based on everything but id and missing status
        for i, v in ipairs(instances) do
            local tmpInstanceA = OD_DeepCopy(instance)
            local tmpInstanceB = OD_DeepCopy(v)
            tmpInstanceA.vst_id = nil
            tmpInstanceB.vst_id = nil
            tmpInstanceA.missing = nil
            tmpInstanceB.missing = nil
            if OD_TableDeepCompare(tmpInstanceA, tmpInstanceB) then
                return true, 'Duplicate instance found',
                    instance.fx_type .. (instance.instrument and 'i:' or ': ') .. instance.full_name
            end
        end
        if instance.vst_id then
            -- check for duplicate IDs - waves plugins are sometimes installed with multiple waveshells that share the same ID
            -- no need to worry about it here, so leave just one. Reaper deals with it when loading the FX
            for i, v in ipairs(instances) do
                if v.vst_id == instance.vst_id then
                    return true, 'Duplicate vst ID found', instance.vst_id
                end
            end
        end
        return false
    end

    if full_name == '' then return false end

    if shouldExclude() then
        self.app.logger:logDebug('Skipping ' .. full_name .. ' - excluded by reaper FX filter',
            self.defaults.fx_filter_string)
        return false
    else
        local success, name, vendor, originalVendor, channels, variant = extractNameVendorChannels(full_name, fx_type)

        if not success then
            self.app.logger:logError('cannot parse plugin name: ' .. full_name)
            return false
        end

        local instance = {
            full_name = full_name,
            name = name,
            vendor = vendor,
            originalVendor = originalVendor, -- this is set if the vendor name was changed to a unified one (see VENDOR_ALIASES)). it is needed for the windowTitleString when getting the hwnd
            channels = channels,
            variant = variant,
            instrument = instrument,
            fx_type = fx_type,
            fx_folder = fx_folder,
            vst_id = vst_id,
            path = args.path,
            missing = false -- this is set to true if the instance is missing
        }

        local key = (fx_type == 'JS' and '_js_' or '') ..
            (instrument and 'i_' or '') .. (vendor and (instance.vendor:lower() .. '_') or '') .. instance.name:lower()
        if self.items.plugins[key] then
            if self.items.plugins[key].onlyMissingInstances then
                self.app.logger:logDebug('Skipping ' .. full_name .. ' - all instances missing')
            else
                local duplicatesExist, msg, msg_val = duplicatesExist(self.items.plugins[key].instances, instance)
                if duplicatesExist then
                    self.app.logger:logDebug('Skipping ' .. full_name .. ' - ' .. msg, msg_val)
                else
                    table.insert(self.items.plugins[key].instances, instance)
                    self.app.logger:logInfo(
                        'Added ' ..
                        fx_type ..
                        (instrument and 'i' or '') .. ' variant to: ' .. name .. (vendor and (' by ' .. vendor) or ''),
                        instance.full_name)
                end
            end
        else
            self.app.temp.scanTotal = self.app.temp.scanTotal + 1
            self.items.plugins[key] = {
                name = name,
                vendor = vendor,
                order = self.app.temp.scanTotal,
                instances = { instance },
                photo = nil,                  -- filename of photo of the plugin
                scanned = false,              -- was the plugin scanned for a photo?
                loaded = nil,                 -- when loading during photo scanning, was it loaded successfully?
                crashed = false,              -- when loading during photo scanning, did it crash reaper
                onlyMissingInstances = false, -- when loading during photo scanning, if all instances are missing, mark the plugin as missing to avoid adding again when scanning
            }
            self.app.logger:logInfo('Added ' ..
                fx_type .. (instrument and 'i' or '') .. ': ' .. name .. (vendor and (' by ' .. vendor) or ''),
                instance.full_name)
        end
        -- add to scanned instances for deleting unscanned instances later
        if self.app.temp.scanned_instances[key] then
            table.insert(self.app.temp.scanned_instances[key], instance)
        else
            self.app.temp.scanned_instances[key] = { instance }
        end
        return true
    end
end
