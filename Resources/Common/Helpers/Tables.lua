-- @noindex

function OD_TableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function OD_HasValue(tab, val, case_indifferent)
    for index, value in ipairs(tab) do
        if case_indifferent and type(val) == string and type(value) == string then
            if value:lower() == val:lower() then return true end
        else
            if value == val then return true end
        end
    end
    return false
end

function OD_RemoveValue(tab, val, case_indifferent)
    for i = #tab, 1, -1 do
        if case_indifferent and type(val) == string and type(tab[i]) == string then
            if tab[i]:lower() == val:lower() then
                table.remove(tab, i)
            end
        else
            if tab[i] == val then
                table.remove(tab, i)
            end
        end
    end
end

function OD_Tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

------------------------------------------- --
-- Pickle.lua
-- A table serialization utility for lua
-- Steve Dekorte, http://www.dekorte.com, Apr 2000
-- (updated for Lua 5.3 by lb0)
-- Freeware
----------------------------------------------
function pickle(t)
    return Pickle:clone():pickle_(t)
end

Pickle = {
    clone = function(t)
        local nt = {};
        for i, v in pairs(t) do
            nt[i] = v
        end
        return nt
    end
}

function Pickle:pickle_(root)
    if type(root) ~= "table" then
        error("can only pickle tables, not " .. type(root) .. "s")
    end
    self._tableToRef = {}
    self._refToTable = {}
    local savecount = 0
    self:ref_(root)
    local s = ""

    while #self._refToTable > savecount do
        savecount = savecount + 1
        local t = self._refToTable[savecount]
        s = s .. "{\n"

        for i, v in pairs(t) do
            s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
        end
        s = s .. "},\n"
    end
    return string.format("{%s}", s)
end

function Pickle:value_(v)
    local vtype = type(v)
    if vtype == "string" then
        return string.format("%q", v)
    elseif vtype == "number" then
        return v
    elseif vtype == "boolean" then
        return tostring(v)
    elseif vtype == "table" then
        return "{" .. self:ref_(v) .. "}"
    else
        error("pickle a " .. type(v) .. " is not supported")
    end
end

function Pickle:ref_(t)
    local ref = self._tableToRef[t]
    if not ref then
        if t == self then
            error("can't pickle the pickle class")
        end
        table.insert(self._refToTable, t)
        ref = #self._refToTable
        self._tableToRef[t] = ref
    end
    return ref
end

----------------------------------------------
-- unpickle
----------------------------------------------

function unpickle(s)
    if s == nil or s == '' then
        return
    end
    if type(s) ~= "string" then
        error("can't unpickle a " .. type(s) .. ", only strings")
    end
    local gentables = load("return " .. s)
    if gentables then
        local tables = gentables()

        if tables then
            for tnum = 1, #tables do
                local t = tables[tnum]
                local tcopy = {};
                for i, v in pairs(t) do
                    tcopy[i] = v
                end
                for i, v in pairs(tcopy) do
                    local ni, nv
                    if type(i) == "table" then
                        ni = tables[i[1]]
                    else
                        ni = i
                    end
                    if type(v) == "table" then
                        nv = tables[v[1]]
                    else
                        nv = v
                    end
                    t[i] = nil
                    t[ni] = nv
                end
            end
            return tables[1]
        end
    else
        -- error
    end
end

--------------------------------------------------------------------------------
-- table.save / table.load -----------------------------------------------------
--------------------------------------------------------------------------------

--[[
    Save Table to File
    Load Table from File
    v 1.0

    Lua 5.2 compatible

    Only Saves Tables, Numbers and Strings
    Insides Table References are saved
    Does not save Userdata, Metatables, Functions and indices of these
    ----------------------------------------------------
    table.save( table , filename )

    on failure: returns an error msg

    ----------------------------------------------------
    table.load( filename or stringtable )

    Loads a table that has been saved via the table.save function

    on success: returns a previously saved table
    on failure: returns as second argument an error msg
    ----------------------------------------------------

    Licensed under the same terms as Lua itself.
  ]]
--

do
    -- declare local variables
    -- // exportstring( string )
    -- // returns a "Lua" portable version of the string
    local function exportstring(s)
        return string.format("%q", s)
    end

    local function exportboolean(b)
        return tostring(b)
    end

    -- // The Save Function
    function table.save(tbl, filename)
        local charS, charE = "   ", "\n"
        local file, err = io.open(filename, "wb")
        if err then
            return err
        end

        -- initiate variables for save procedure
        local tables, lookup = { tbl }, {
            [tbl] = 1
        }
        if file then
            file:write("return {" .. charE)

            for idx, t in ipairs(tables) do
                file:write("-- Table: {" .. idx .. "}" .. charE)
                file:write("{" .. charE)
                local thandled = {}

                for i, v in ipairs(t) do
                    thandled[i] = true
                    local stype = type(v)
                    -- only handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert(tables, v)
                            lookup[v] = #tables
                        end
                        file:write(charS .. "{" .. lookup[v] .. "}," .. charE)
                    elseif stype == "string" then
                        file:write(charS .. exportstring(v) .. "," .. charE)
                    elseif stype == "number" then
                        file:write(charS .. tostring(v) .. "," .. charE)
                    elseif stype == "boolean" then -- edit to original to allow saving booleans
                        file:write(charS .. exportboolean(v) .. "," .. charE)
                    end
                end

                for i, v in pairs(t) do
                    -- escape handled values
                    if (not thandled[i]) then
                        local str = ""
                        local stype = type(i)
                        -- handle index
                        if stype == "table" then
                            if not lookup[i] then
                                table.insert(tables, i)
                                lookup[i] = #tables
                            end
                            str = charS .. "[{" .. lookup[i] .. "}]="
                        elseif stype == "string" then
                            str = charS .. "[" .. exportstring(i) .. "]="
                        elseif stype == "number" then
                            str = charS .. "[" .. tostring(i) .. "]="
                        elseif stype == "boolean" then -- edit to original to allow saving booleans
                            str = charS .. "[" .. exportboolean(i) .. "]="
                        end

                        if str ~= "" then
                            stype = type(v)
                            -- handle value
                            if stype == "table" then
                                if not lookup[v] then
                                    table.insert(tables, v)
                                    lookup[v] = #tables
                                end
                                file:write(str .. "{" .. lookup[v] .. "}," .. charE)
                            elseif stype == "string" then
                                file:write(str .. exportstring(v) .. "," .. charE)
                            elseif stype == "number" then
                                file:write(str .. tostring(v) .. "," .. charE)
                            elseif stype == "boolean" then
                                file:write(str .. exportboolean(v) .. "," .. charE)
                            end
                        end
                    end
                end
                file:write("}," .. charE)
            end
            file:write("}")
            file:close()
        end
    end

    -- // The Load Function
    function table.load(sfile)
        local fs = io.open(sfile, "r") -- edit to original
        if not fs then
            return {}
        end
        local str = fs:read("*all") -- checking the contents of the config file to make sure its just a table
        fs:close()

        local ftables, err = loadfile(sfile)
        if err then
            return nil
        end
        if not ftables then return nil end
        local tables = ftables()
        for idx = 1, #tables do
            local tolinki = {}
            for i, v in pairs(tables[idx]) do
                if type(v) == "table" then
                    tables[idx][i] = tables[v[1]]
                end
                if type(i) == "table" and tables[i[1]] then
                    table.insert(tolinki, { i, tables[i[1]] })
                end
            end
            -- link indices
            for _, v in ipairs(tolinki) do
                tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
            end
        end
        return tables[1]
    end

    -- close do
end

-- Save copied tables in `copies`, indexed by original table.
-- returnes a copy of the original table
function OD_DeepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[OD_DeepCopy(orig_key, copies)] = OD_DeepCopy(orig_value, copies)
            end
            setmetatable(copy, OD_DeepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- alters the first table with the second
function OD_MergeTables(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            OD_MergeTables(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end

function OD_PairsByOrder(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, function(a, b)
        return t[a].order < t[b].order
    end)
    local i = 0 -- iterator variable
    local iter = function()
        -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

function OD_TableMap(t, f)
    local newTable = {}
    for k, v in pairs(t) do
        newTable[k] = f(k, v)
    end
    return newTable
end

function OD_TableFilter(t, f)
    local newTable = {}
    for k, v in pairs(t) do
        if f(k, v) then
            newTable[k] = v
        end
    end
    return newTable
end
