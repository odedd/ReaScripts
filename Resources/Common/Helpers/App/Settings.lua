-- @noindex
-- ! OD_Settings
OD_Settings = {
    current = {},
    default = {},  -- values to be merged with and overwritten by those the user changes. Merge happens ON EACH LOAD.
    initial = nil, -- should contain settings that only need to be set to new instances, but unlike default - they won't get copied on each load - only when reset to factory or when there's no settings file saved yet.
    dfsetfile = nil
}

function OD_Settings:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

function OD_Settings:init()
    if self.dfsetfile == nil then
        error('OD_Settings: dfsetfile not set')
    end
end

function OD_Settings:getDefault(factory)
    if factory == nil then factory = false end
    local st = {
        default = OD_DeepCopy(self.default)
    }
    if (factory or not OD_FileExists(self.dfsetfile)) and self.initial then
        st.default = OD_MergeTables(st.default, self.initial)
    end
    if not factory then
        local loaded_ext_settings = table.load(self.dfsetfile) or {}
        st.default = OD_MergeTables(st.default, loaded_ext_settings)
        -- for k, v in pairs(loaded_ext_settings or {}) do
        --     if type(v) == 'table' then
        --         -- st.default[k] = v
        --         st.default[k] = OD_MergeTables(st.default[k], v)
        --     else
        --         st.default[k] = v
        --     end
        -- end
    end
    return st
end

function OD_Settings:load()
    local st = self:getDefault()
    OD_MergeTables(self.current, st.default)
end

function OD_Settings:save()
    table.save(self.current, self.dfsetfile)
end

function OD_Settings:check()
    local errors = {}
    if false then
        table.insert(errors, 'no settings check implemented')
    end
    return #errors == 0, errors
end
