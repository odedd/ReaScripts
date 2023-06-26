-- @noindex
-- ! OD_Settings
OD_Settings = {
    current = {},
    default = {},
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
        default = self.default
    }

    if not factory then
        local loaded_ext_settings = table.load(self.dfsetfile) or {}
        for k, v in pairs(loaded_ext_settings or {}) do
            st.default[k] = v
        end
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