-- @noindex

function OD_EscapeCSV(str)
    if not str then return "" end
    -- Escape commas, colons, newlines, and backslashes
    str = tostring(str)
    str = str:gsub("\\", "\\\\")  -- Escape backslashes first
    str = str:gsub(",", "\\,")    -- Escape commas
    str = str:gsub(":", "\\:")    -- Escape colons  
    str = str:gsub("\n", "\\n")   -- Escape newlines
    str = str:gsub("\r", "\\r")   -- Escape carriage returns
    return str
end

function OD_UnescapeCSV(str)
    if not str then return "" end
    -- Unescape in reverse order
    str = str:gsub("\\r", "\r")   -- Unescape carriage returns
    str = str:gsub("\\n", "\n")   -- Unescape newlines
    str = str:gsub("\\:", ":")    -- Unescape colons
    str = str:gsub("\\,", ",")    -- Unescape commas
    str = str:gsub("\\\\", "\\")  -- Unescape backslashes last
    return str
end

function OD_ParseCSVLine(line, separator)
    separator = separator or ","
    local fields = {}
    local field = ""
    local i = 1
    local inEscape = false
    
    while i <= #line do
        local char = line:sub(i, i)
        
        if inEscape then
            -- Previous character was backslash, add current char literally
            field = field .. char
            inEscape = false
        elseif char == "\\" then
            -- Start escape sequence
            inEscape = true
        elseif char == separator then
            -- Field separator found
            table.insert(fields, OD_UnescapeCSV(field))
            field = ""
        else
            -- Regular character
            field = field .. char
        end
        
        i = i + 1
    end
    
    -- Add the last field
    table.insert(fields, OD_UnescapeCSV(field))
    return fields
end

function OD_FindUnescapedChar(line, char)
    local pos = nil
    local i = 1
    local inEscape = false
    
    -- Find the first unescaped occurrence of char
    while i <= #line do
        local currentChar = line:sub(i, i)
        if inEscape then
            inEscape = false
        elseif currentChar == "\\" then
            inEscape = true
        elseif currentChar == char then
            pos = i
            break
        end
        i = i + 1
    end
    
    return pos
end
