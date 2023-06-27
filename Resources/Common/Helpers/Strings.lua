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

function OD_MagicFix(str)
  return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
end

function OD_CaseInsensitivePattern(pattern)

  
    -- find an optional '%' (group 1) followed by any character (group 2)
    local classStarted = false
    local p = pattern:gsub("(%%?)(.)", function(percent, letter)
      
      if percent ~= "" or not letter:match("%a") or classStarted then
        if letter == '[' then 
          classStarted = true
        elseif letter == ']' then
          classStarted = false
        end
        -- if the '%' matched, or `letter` is not a letter, return "as is"
        return percent .. letter
      elseif not classStarted then
        -- else, return a case-insensitive character class of the matched letter 
        return string.format("[%s%s]", letter:lower(), letter:upper())
      end
  
    end)
  
    return p
  end
function OD_Trim(s)
    return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

-- function magicFix(str)
--     return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
--   end
  


local function _is_not_sanitized_posix(str)
  -- A sanitized string must be quoted.
  if not string.match(str, "^'.*'$") then
      return true
  -- A quoted string containing no quote characters within is sanitized.
  elseif string.match(str, "^'[^']*'$") then
      return false
  end
  
  -- Any quote characters within a sanitized string must be properly
  -- escaped.
  local quotesStripped = string.sub(str, 2, -2)
  local escapedQuotesRemoved = string.gsub(quotesStripped, "'\\''", "")
  if string.find(escapedQuotesRemoved, "'") then
      return true
  else
      return false
  end
end
-- from dtutils
local function _is_not_sanitized_windows(str)
  if not string.match(str, "^\".*\"$") then
     return true
  else
     return false
  end
end
-- from dtutils
function OD_IsNotSanitized(str)
 if OS_is.win == "windows" then
     return _is_not_sanitized_windows(str)
 else
     return _is_not_sanitized_posix(str)
 end
end
-- from dtutils
local function _sanitize_posix(str)
 if _is_not_sanitized_posix(str) then
     return "'" .. string.gsub(str, "'", "'\\''") .. "'"
 else
      return str
 end
end
-- from dtutils
local function _sanitize_windows(str)
 if _is_not_sanitized_windows(str) then
     return "\"" .. string.gsub(str, "\"", "\"^\"\"") .. "\""
 else
     return str
 end
end

-- from dtutils
function OD_Sanitize(str)
 if OS_is.win then
     return _sanitize_windows(str)
 else
     return _sanitize_posix(str)
 end
end