-- @noindex

string.split = function(s, delimiter)
    result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

function escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end