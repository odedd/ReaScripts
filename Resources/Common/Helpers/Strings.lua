-- @noindex

function OD_Split (s, delimiter)
    local result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

function OD_EscapePattern(text)
    return text:gsub("([^%w])", "%%%1")
end

function OD_Trim(s)
    return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- function magicFix(str)
--     return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
--   end
  