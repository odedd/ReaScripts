-- @noindex

function OD_Split (s, delimiter)
    result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

function OD_EscapePattern(text)
    return text:gsub("([^%w])", "%%%1")
end