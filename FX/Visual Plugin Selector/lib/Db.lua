-- @noindex
-- ! OD_Db
OD_VPS_DB = {
    paths = {},
    items = {
        plugins = {}
    },
    PLUGIN = {
        VARIANT = {
            MONO = 'mono',
            STEREO = 'stereo',
            MONO_TO_STEREO = 'mono to stereo',
            STEREO_TO_5_0 = 'stereo to 5.0',
            STEREO_TO_5_1 = 'stereo to 5.1',
            OTHER = 'OTHER',
        }
    }
}

function OD_VPS_DB:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

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
end

function OD_VPS_DB:getFXfolder(str, type_n)
    str = str:lower()
    local fx_folder = ""

    if not str then return fx_folder end

    -- if config and not config.fol_search then return fx_folder end

    if type_n == 3 then -- if VST
        local vst_id, vst_file = str:match("(.-)//(.+)")
        vst_id = vst_id:gsub("{%w+", "")

        for i = 1, self.fx_folders and #self.fx_folders or 0 do
            if self.fx_folders[i].content and (vst_id ~= "0" and self.fx_folders[i].content:find(vst_id) or
                    self.fx_folders[i].content:find(vst_file .. "[\n\r]")) then
                fx_folder = fx_folder .. "\t" .. self.fx_folders[i].name
            end
        end
    else
        str = str:gsub("[^%w%.\n\r]", "_")

        -- ? instead of OD_EscapePattern maybe should use magicFix from Quick Adder 2
        for i = 1, self.fx_folders and #self.fx_folders or 0 do
            if self.fx_folders[i].content and self.fx_folders[i].content:match("item%d+_" .. OD_EscapePattern(str)) then
                local fx_n = self.fx_folders[i].content:match("item(%d+)_" .. OD_EscapePattern(str))

                if self.fx_folders[i].content:find("type" .. fx_n .. "_" .. type_n) then
                    fx_folder = fx_folder .. "\t" .. self.fx_folders[i].name
                end
            end
        end
    end

    return fx_folder
end

function OD_VPS_DB:scan()
    local fx_folders_ini = OD_GetContent(self.paths.fx_folders)

    if fx_folders_ini then
        fx_folders_ini = fx_folders_ini .. "\n\n"
        local folder_names = fx_folders_ini:match("%[Folders%](.-)\n[\n%[]")
        if folder_names then
            self.fx_folders = {}
            for match in folder_names:gmatch("Name%d+=.-\n") do
                local n, name = match:match("Name(%d+)=(.+)\n")
                self.fx_folders[n + 1] = { name = name }
            end

            for match in fx_folders_ini:gmatch("(Folder%d+%].-)\n[\n%[]") do
                local n, content = match:match("Folder(%d+)%](.+)")
                self.fx_folders[n + 1].content = content:gsub("[^%w%.\n\r]", "_"):lower()
            end
            fx_folders_ini = nil
        end
    end

    self:getVst()
end

-- adapted from Quick Adder 2 by neutronic
function OD_VPS_DB:getVst()
    local cntr = 0
    local content = OD_GetContent(self.paths.vst)
    for line in content:gmatch(".-\n") do
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

        -- if rpr.def_fx_filt and fxExclCheck(fx_type:lower():gsub("vst2", "vst") .. vst_name:lower()) then goto SKIP end
        -- if rpr.def_fx_filt and not fxExclCheck(fx_type:lower():gsub("vst2", "vst") .. vst_name:lower(), true) then goto SKIP end

        local fx_folder = self:getFXfolder(vst_id .. "//" .. vst_file, 3)
        
        self:addPlugin(vst_name, fx_folder, fx_type, vst_file, vsti, vst_id)
        -- if select(2, math.modf(cntr % 10)) == 0 then
        coroutine.yield()
        -- end
        cntr = cntr + 1
        ::SKIP::
    end
end

function OD_VPS_DB:addPlugin(vst_name, fx_folder, fx_type, vst_file, vsti, vst_id)
    if vst_name == '' then return false end
    local name, vendor, channels, variant
    name, vendor, channels = vst_name:match('(.+)%s%((.+)%)%s%((.*%dch)%)$')
    if not channels then -- channels are sometimes reffered to as "%d out"
        name, vendor, channels = vst_name:match('(.+)%s%((.+)%)%s%((%d*%sout)%)$')
    end
    if not channels then -- when there's only one channel it's reffered to as "mono"
        name, vendor, channels = vst_name:match('(.+)%s%((.+)%)%s%((mono)%)$')
    end

    if not vendor then
        name, vendor = vst_name:match('(.+)%s%((.+)%)')
    end

    if name:lower():match(' mono$') then
        variant = self.PLUGIN.VARIANT.MONO
        name = name:gsub(' mono$', '')
    elseif name:lower():match(' stereo$') then
        variant = self.PLUGIN.VARIANT.STEREO
        name = name:gsub(' stereo$', '')
    elseif name:lower():match(' mono/stereo$') then
        variant = self.PLUGIN.VARIANT.MONO_STEREO
        name = name:gsub(' mono/stereo$', '')
    elseif name:lower():match(' stereo/5%.0$') then
        variant = self.PLUGIN.VARIANT.STEREO_5_0
        name = name:gsub(' stereo/5%.0$', '')
    elseif name:lower():match(' stereo/5%.1$') then
        variant = self.PLUGIN.VARIANT.STEREO_5_1
        name = name:gsub(' stereo/5%.1$', '')
    end

    local pluginInfo = {
        full_name = vst_name,
        name = name,
        vendor = vendor,
        channels = channels,
        variant = variant,
        vsti = vsti,
        fx_type = fx_type,
        fx_folder = fx_folder,
        vst_file = vst_file,
        vst_id = vst_id
    }

    local key = vendor:lower() .. '_' .. name:lower()
    if self.items.plugins[key] then
        table.insert(self.items.plugins[key].instances, pluginInfo)
        -- reaper.ShowConsoleMsg('added variant to ' .. name .. ' by ' .. vendor .. '\n')
    else
        self.items.plugins[key] = { instances = { pluginInfo } }
        -- reaper.ShowConsoleMsg('added ' .. name .. ' by ' .. vendor .. '\n')
    end
    return true
end
