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
    -- Process escape sequences to reverse exactly what OD_EscapeCSV does
    -- For asset keys (file paths), \n and \r are always literal parts of Windows paths,
    -- never actual newline/carriage return characters
    
    -- DEBUG: Test the specific case we're seeing
    
    str = str:gsub("\\(.)", function(c)
        if c == "\\" then return "\\"      -- \\\\ -> \ (restore backslash)
        elseif c == ":" then return ":"    -- \\: -> : (restore colon)
        elseif c == "," then return ","    -- \\, -> , (restore comma)
        elseif c == "n" then return "\n"  -- \\n -> \n (literal backslash + n, not newline)
        elseif c == "r" then return "\r"  -- \\r -> \r (literal backslash + r, not carriage return)
        else return "\\" .. c              -- Keep unknown escapes as literal backslash + character
        end
    end)
    
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
    if not line or not char then return nil end
    
    -- Fast path: if no backslashes, just use string.find
    if not line:find("\\", 1, true) then
        return line:find(char, 1, true)
    end
    
    -- Use pattern matching for better performance
    local pos = 1
    while pos <= #line do
        local foundPos = line:find(char, pos, true)
        if not foundPos then
            return nil  -- Character not found
        end
        
        -- Count consecutive backslashes before this position
        local backslashCount = 0
        local checkPos = foundPos - 1
        while checkPos > 0 and line:sub(checkPos, checkPos) == "\\" do
            backslashCount = backslashCount + 1
            checkPos = checkPos - 1
        end
        
        -- If even number of backslashes (or zero), character is not escaped
        if backslashCount % 2 == 0 then
            return foundPos
        end
        
        -- Character is escaped, continue searching after this position
        pos = foundPos + 1
    end
    
    return nil
end
