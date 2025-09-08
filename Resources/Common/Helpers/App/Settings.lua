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

function OD_Settings:getDefault(factory, listsToUpdate)
    if factory == nil then factory = false end
    local st = {
        default = OD_DeepCopy(self.default)
    }
    if (factory or not OD_FileExists(self.dfsetfile)) and self.initial then
        st.default = OD_MergeTables(st.default, self.initial)
    end
    if not factory then
        local loaded_ext_settings = table.load(self.dfsetfile) or {}

        if listsToUpdate then
            -- local updated = false
            for _, listName in ipairs(listsToUpdate) do
                local defaultList = st.default[listName]
                local currentList = loaded_ext_settings[listName]
                if currentList then
                    if type(self.default[listName]) == "table" then
                        if OD_IsList(defaultList) then
                            for i, item in ipairs(defaultList) do
                                if not OD_HasValue(currentList, item) then
                                    table.insert(currentList, item)
                                    -- updated = true
                                end
                            end
                            for i = #currentList, 1, -1 do
                                local item = currentList[i]
                                if not OD_HasValue(defaultList, item) then
                                    table.remove(currentList, i)
                                    -- updated = true
                                end
                            end
                        end
                    end
                end
            end
        end
        st.default = OD_MergeTables(st.default, loaded_ext_settings)
    end
    return st
end

function OD_Settings:load(listsToUpdate)
    local st = self:getDefault(false, listsToUpdate)
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
